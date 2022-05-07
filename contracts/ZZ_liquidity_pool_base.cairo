%lang starknet

from starkware.cairo.common.uint256 import Uint256, uint256_le
from starkware.starknet.common.syscalls import get_block_timestamp
from starkware.cairo.common.math import assert_not_zero

from openzeppelin.security.safemath import (
    uint256_checked_add, uint256_checked_mul, uint256_checked_sub_le, uint256_checked_div_rem)
from openzeppelin.utils.constants import TRUE, FALSE

from contracts.lib.mammoth_pool.contracts.lib.Pool_base import Pool_deposit, Pool_withdraw
from contracts.Time_window_base import TimeWindow

from config import ZZ_TOKEN_ADDRESS, ZZ_EXCHANGE_ADDRESS, BLACKOUT, NONBLACKOUT

################
# STORAGE
################

# address of zigzag exchange contract
@storage
func exchange_contract() -> (address : felt):
end

# address of active rewards contract
@storage
func current_rewards_contract() -> (address : felt):
end

# is a user an active pool depositer
@storage
func is_user_active(user_address : felt) -> (bool : felt):
end

# balance a user has staked at the current time
@storage
func user_total_staked(user_address : felt) -> (amount : Uint256):
end

# active stake of the user
@storage
func user_active_stake(user_address : felt) -> (active_amount : Uint256):
end

# inactive stake of the user
@storage
func user_inactive_stake(user_address : felt) -> (inactive_amount : Uint256):
end

# TODO: add in monitoring of the total stakes

# total stake
@storage
func total_stake() -> (total : Uint256):
end

# total active stake
@storage
func total_active_stake() -> (total_active : Uint256):
end

# total inactive stake
@storage
func total_inactive_stake() -> (total_inactive : Uint256):
end

namespace Liquidity_Pool:
    ################
    # DEPOSIT FUNCTIONS
    ################

    # NOTE: for all deposit functions user must first approve the pool to transferFrom

    func deposit{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
            amount_to_deposit : Uint256, user_address : felt, erc20_address : felt) -> (
            success : felt):
        alloc_locals

        let (local deposit_success : felt) = Pool_deposit(
            amount=amount_to_deposit, address=user_address, erc20_address=erc20_address)
        assert deposit_success = TRUE

        # activate user
        is_user_active.write(user_address, TRUE)

        let (local current_active_stake : Uint256) = user_active_stake.read(user_address)
        let (local current_total_stake : Uint256) = user_total_staked.read(user_address)

        # calculate new stakes
        local new_active_stake : Uint256 = uint256_checked_add(current_active_stake, amount_to_deposit)
        local new_total_stake : Uint256 = uint256_checked_add(current_total_stake, amount_to_deposit)

        user_active_stake.write(user_address, new_active_stake)
        user_total_staked.write(user_address, new_total_stake)

        # update total stakes
        let (local current_total_active_stake : Uint256) = total_active_stake.read()
        let (local current_overall_total_stake : Uint256) = total_stake.read()

        local new_overall_active_stake : Uint256 = uint256_checked_add(current_total_active_stake, amount_to_deposit)
        local new_overall_total_stake : Uint256 = uint256_checked_add(current_overall_total_stake, amount_to_deposit)

        total_active_stake.write(new_overall_active_stake)
        total_stake.write(new_overall_total_stake)

        return (TRUE)
    end

    ################
    # WITHDRAW FUNCTION
    ################

    # TODO: put in main contract
    # check that withdrawer has the required amount of lp tokens
    # let (local user_lp_balance : Uint256) = Mintable_ERC.balanceOf(
    #    contract_address=ZZ_TOKEN_ADDRESS, account=user_address)

    # with_attr error_message("not enough LP tokens"):
    #    let (local le : felt) = uint256_le(amount_of_lp_to_deposit, user_lp_balance)
    #    assert le = TRUE
    # end

    # burn LP tokens
    # Mintable_ERC.burn(
    #    contract_address=ZZ_TOKEN_ADDRESS, account=user_address, amount=amount_of_lp_to_deposit)
    func withdraw{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
            amount_to_withdraw : Uint256, user_address : felt, erc20_address : felt) -> (
            success : felt):
        alloc_locals

        # TODO: move to main contract
        # check in appropriate time window
        let (local mode : felt) = TimeWindow.get_current_mode()

        with_attr error_message("BLACKOUT WINDOW - WITHDRAW UNAVAILABLE"):
            assert mode = NONBLACKOUT
        end

        # check user has enough inactive balance
        let (local current_inactive_stake : Uint256) = user_inactive_stake.read(user_address)
        let (local le : felt) = uint256_le(amount_to_withdraw, current_inactive_stake)

        with_attr error_message("not enough inactive balance to fulfill withdrawal request"):
            assert le = TRUE
        end

        let (local withdraw_success : felt) = Pool_withdraw(
            amount=amount_to_withdraw, address=user_address, erc20_address=erc20_address)
        assert withdraw_success = TRUE

        # update storage vars
        let (local current_total_stake) = user_total_staked.read(user_address)

        # calculate new stakes
        local new_inactive_stake : Uint256 = uint256_checked_sub_le(current_inactive_stake, amount_to_withdraw)
        local new_total_stake : Uint256 = uint256_checked_sub_le(current_total_stake, amount_to_withdraw)

        user_inactive_stake.write(user_address, new_inactive_stake)
        user_total_staked.write(user_address, new_total_stake)

        # update total stake
        let (local current_total_inactive_stake : Uint256) = total_inactive_stake.read()
        let (local current_overall_total_stake : Uint256) = total_stake.read()

        local new_overall_inactive_stake : Uint256 = uint256_checked_sub_le(current_total_inactive_stake, amount_to_withdraw)
        local new_overall_total_stake : Uint256 = uint256_checked_sub_le(current_overall_total_stake, amount_to_withdraw)

        total_inactive_stake.write(new_overall_inactive_stake)
        total_stake.write(new_overall_total_stake)

        return (TRUE)
    end

    func dactivate{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
            amount_to_deactivate : Uint256, user_address : felt) -> (success : felt):
        alloc_locals

        let (local current_active_stake : Uint256) = user_active_stake.read(user_address)
        let (local current_inactive_stake : Uint256) = user_inactive_stake.read(user_address)

        let (local new_active_stake : Uint256) = uint256_checked_sub_le(
            current_active_stake, amount_to_deactivate)
        let (local new_inactive_stake : Uint256) = uint256_checked_add(
            current_inactive_stake, amount_to_deactivate)

        user_active_stake.write(user_address, new_active_stake)
        user_inactive_stake.write(user_address, new_inactive_stake)

        # update total stake
        let (local current_total_inactive_stake : Uint256) = total_inactive_stake.read()
        let (local current_overall_active_stake : Uint256) = total_active_stake.read()

        local new_overall_inactive_stake : Uint256 = uint256_checked_add(current_total_inactive_stake, amount_to_deactivate)
        local new_overall_active_stake : Uint256 = uint256_checked_sub_le(current_overall_total_stake, amount_to_deactivate)

        total_inactive_stake.write(new_overall_inactive_stake)
        total_active_stake.write(new_overall_active_stake)

        return (TRUE)
    end

    func reactivate{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
            amount_to_reactivate : Uint256, user_address : felt) -> (success : felt):
        alloc_locals

        let (local current_active_stake : Uint256) = user_active_stake.read(user_address)
        let (local current_inactive_stake : Uint256) = user_inactive_stake.read(user_address)

        let (local new_active_stake : Uint256) = uint256_checked_add(
            current_active_stake, amount_to_reactivate)
        let (local new_inactive_stake : Uint256) = uint256_checked_sub_le(
            current_inactive_stake, amount_to_reactivate)

        user_active_stake.write(user_address, new_active_stake)
        user_inactive_stake.write(user_address, new_inactive_stake)

        # update total stake
        let (local current_total_inactive_stake : Uint256) = total_inactive_stake.read()
        let (local current_overall_active_stake : Uint256) = total_active_stake.read()

        local new_overall_inactive_stake : Uint256 = uint256_checked_sub_le(current_total_inactive_stake, amount_to_reactivate)
        local new_overall_active_stake : Uint256 = uint256_checked_add(current_overall_total_stake, amount_to_reactivate)

        total_inactive_stake.write(new_overall_inactive_stake)
        total_active_stake.write(new_overall_active_stake)

        return (TRUE)
    end
end

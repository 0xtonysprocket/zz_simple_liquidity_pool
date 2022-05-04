%lang starknet

from starkware.cairo.common.uint256 import Uint256, uint256_le
from starkware.starknet.common.syscalls import get_block_timestamp
from starkware.cairo.common.math import assert_not_zero

from openzeppelin.security.safemath import (
    uint256_checked_add, uint256_checked_mul, uint256_checked_div_rem)
from openzeppelin.utils.constants import TRUE, FALSE

from contracts.lib.mammoth_pool.contracts.lib.Pool_base import Pool_deposit, Pool_withdraw
from contracts.Time_window_base import TimeWindow

from config import ZZ_TOKEN_ADDRESS, ZZ_EXCHANGE_ADDRESS, BLACKOUT, NONBLACKOUT

################
# INTERFACES
################

@contract_interface
namespace ERC:
    func balanceOf(account : felt) -> (balance : Uint256):
    end

    func transfer(recipient : felt, amount : Uint256) -> (success : felt):
    end
end

@contract_interface
namespace Mintable_ERC:
    func mint(to : felt, amount : Uint256):
    end

    func burn(account : felt, amount : Uint256):
    end

    func totalSupply() -> (totalSupply : Uint256):
    end

    func balanceOf(account : felt) -> (balance : Uint256):
    end
end

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

# whitelisted mm_accounts
@storage
func mm_account_whitelist(mm_address : felt) -> (bool : felt):
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

@storage
func beginning_of_pool_timestamp() -> (time : felt):
end

################
# DEPOSIT FUNCTIONS
################

# NOTE: for all deposit functions user must first approve the pool to transferFrom

func Liquidity_pool_deposit{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount_to_deposit : Uint256, user_address : felt, erc20_address : felt) -> (success : felt):
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

    return (TRUE)
end

################
# WITHDRAW FUNCTION
################

func Liquidity_pool_withdraw{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount_of_lp_to_deposit : Uint256, user_address : felt, erc20_address : felt) -> (
        success : felt):
    alloc_locals

    # check in appropriate time window
    let (local mode : felt) = TimeWindow.get_current_mode()

    with_attr error_message("BLACKOUT WINDOW - WITHDRAW UNAVAILABLE"):
        assert mode = NONBLACKOUT
    end

    # check user has enough inactive balance
    let (local inactive_balance : Uint256) = user_inactive_stake.read(user_address)
    let (local le : felt) = uint256_le(amount_of_lp_to_deposit, inactive_balance)

    with_attr error_message("not enough inactive balance to fulfill withdrawal request"):
        assert le = TRUE
    end

    let (local withdraw_success : felt) = Pool_withdraw(
        amount=amount_of_lp_to_deposit, address=user_address, erc20_address=erc20_address)
    assert withdraw_success = TRUE

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
    return (TRUE)
end

################
# UTIL
################

# TODO: move to rewards contract
func _update_weighted_average_timestamp{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        new_lp_minted : Uint256, user_address : felt) -> (success : bool):
    alloc_locals

    let (local current_balance : Uint256) = Mintable_ERC.balanceOf(
        contract_address=ZZ_TOKEN_ADDRESS, account=user_address)
    let (local current_average_time : felt) = user_weighted_average_time.read(user_address)
    let (local current_timestamp : felt) = get_block_timestamp()
    let (local timestamp_delta : felt) = current_timestamp - current_average_time + 1
end

# storage exchange_contract, LP_per_WSATOSHI, LP_per_WEI, LP_per_USDC_last_decimal, user_weighted_average_timestamp, zz_reward_per_LP
# funcs deposit_btc, deposit_eth, deposit_usdc, withdraw, view_ZZ_reward, claim_ZZ_reward, transfer_WBTC, transfer_ETH, transfer_USDC
#

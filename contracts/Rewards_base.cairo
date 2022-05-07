%lang starknet

from openzeppelin.security.safemath import (
    uint256_checked_add, uint256_checked_mul, uint256_checked_sub_le, uint256_checked_div_rem)
from openzeppelin.utils.constants import TRUE, FALSE

from starkware.starknet.common.syscalls import get_block_timestamp

# Rate that LP holders accrue ZZ token per LP token per second, SET IN CONSTRUCTOR
@storage
func zz_token_rate() -> (reward : Uint256):
end

# Rate for senior holders ZZ token reward per LP token held per second
# @storage
# func senior_zz_token_rate() -> (reward : Uint256):
# end

# Rate for junior holders ZZ token reward per LP token held per second
# @storage
# func junior_zz_token_rate() -> (reward : Uint256):
# end

# pool contract, SET IN CONSTRUCTOR
@storage
func pool_contract() -> (address : felt):
end

# zz contract
@storage
func zz_token_address() -> (address : felt):
end

# ZZ token reward per LP token held per second
@storage
func user_weighted_average_timestamp(user_account : felt) -> (timestamp : felt):
end

################
# INTERFACES
################

@contract_interface
namespace Liquidity_Pool:
    func balanceOf(account : felt) -> (balance : Uint256):
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

# calculate rewards

func calculate_reward{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        user_address : felt) -> (reward : Uint256):
    alloc_locals

    # read from storage
    let (local pool : felt) = pool_contract.read()
    let (local start_time : felt) = user_weighted_average_timestamp.read(user_address)
    let (local zz_rate : Uint256) = zz_token_rate.read()

    # syscall
    let (local current_time : felt) = get_block_timestamp()

    # LP token balance
    let (local LP_balance : Uint256) = Liquidity_Pool.balanceOf(
        constract_address=pool, account=user_address)

    # calculate time delta and convert Uint256
    let (local time_delta : Uint256) = Uint256(current_time - start_time, 0)

    let (local per_lp : Uint256) = uint256_checked_mul(time_delta, zz_rate)
    let (local reward : Uint256) = uint256_checked_mul(per_lp, LP_balance)

    return (reward)
end

# claim rewards
func claim_reward{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        user_address : felt) -> (reward : Uint256):
    alloc_locals

    let (local zz_token_contract : felt) = zz_token_address.read()
    let (local reward : Uint256) = calculate_reward(user_address)

    with_attr error_message("FAILED TO MINT LP TOKEN"):
        Mintable_ERC.mint(contract_address=zz_token_contract, to=user_address, amount=reward)
    end

    let (local update_success : felt) = update_weighted_average_timestamp(user_address, 0)

    with_attr error_message("failed to update time"):
        assert update_success = TRUE
    end
end

# update timestamp

func update_weighted_average_timestamp{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        user_address : felt, new_lp_balance : Uint256) -> (success : bool):
    alloc_locals

    # syscall
    let (local current_time : felt) = get_block_timestamp()

    if new_lp_balance == 0:
        user_weighted_average_timestamp.write(user_address, current_time)
        return (TRUE)
    end

    let (local zz_rate : Uint256) = zz_token_rate.read()
    let (local current_accrued_reward : Uint256) = calculate_reward(user_address)

    # solve (zz_rate * new_lp_balance)*(0 - x) = current_accrued_reward
    let (local new_per_second : Uint256) = uint256_checked_mul(zz_rate, new_lp_balance)
    let (local new_time_delta : Uint256, _) = uint256_checked_div_rem(
        current_accrued_reward, new_per_second)

    # current_time - new_time_delta
    let (local new_weighted_timestamp : Uint256) = uint256_checked_sub_le(
        current_time, new_time_delta)

    user_weighted_average_timestamp.write(user_address, new_weighted_timestamp)

    return (TRUE)
end

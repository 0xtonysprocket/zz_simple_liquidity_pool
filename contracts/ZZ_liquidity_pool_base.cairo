%lang starknet

from starkware.cairo.common.uint256 import Uint256, uint256_le
from starkware.starknet.common.syscalls import get_block_timestamp
from starkware.cairo.common.math import assert_not_zero

from openzeppelin.security.safemath import uint256_checked_mul, uint256_checked_div_rem
from openzeppelin.utils.constants import TRUE, FALSE

from contracts.lib.mammoth_pool.contracts.lib.Pool_base import Pool_deposit, Pool_withdraw

from config import (
    WBTC_ADDRESS, ETH_ADDRESS, USDC_ADDRESS, ZZ_TOKEN_ADDRESS, ZZ_EXCHANGE_ADDRESS, REWARD_INTERVAL)

################
# INTERFACES
################

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

@contract_interface
namespace ERC:
    func balanceOf(account : felt) -> (balance : Uint256):
    end

    func transfer(recipient : felt, amount : Uint256) -> (success : felt):
    end
end

################
# STORAGE
################

# address of zigzag exchange contract
@storage
func exchange_contract() -> (address : felt):
end

# number of LP tokens being offered per wbtc
@storage
func lp_token_offer_per_wbtc() -> (reward : Uint256):
end

# number of LP tokens being offered per eth
@storage
func lp_token_offer_per_eth() -> (reward : Uint256):
end

# number of LP tokens being offered per USDC
@storage
func lp_token_offer_per_USDC() -> (reward : Uint256):
end

# ZZ token reward per LP token held per 3600 seconds
@storage
func zz_token_per_USDC() -> (reward : Uint256):
end

# ZZ token reward per LP token held per 3600 seconds
@storage
func user_weighted_average_timestamp(user_account : felt) -> (timestamp : felt):
end

################
# DEPOSIT FUNCTIONS
################

# NOTE: for all deposit functions user must first approve the pool to transferFrom

func Liquidity_pool_deposit_WBTC{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount_to_deposit : Uint256, user_address : felt) -> (success : felt):
    alloc_locals

    let (local deposit_success : felt) = Pool_deposit(
        amount=amount_to_deposit, address=user_address, erc20_address=WBTC_ADDRESS)
    assert deposit_success = TRUE
    return (TRUE)
end

func Liquidity_pool_deposit_ETH{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount_to_deposit : Uint256, user_address : felt) -> (success : felt):
    alloc_locals

    let (local deposit_success : felt) = Pool_deposit(
        amount=amount_to_deposit, address=user_address, erc20_address=ETH_ADDRESS)
    assert deposit_success = TRUE
    return (TRUE)
end

func Liquidity_pool_deposit_USDC{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount_to_deposit : Uint256, user_address : felt) -> (success : felt):
    alloc_locals

    let (local deposit_success : felt) = Pool_deposit(
        amount=amount_to_deposit, address=user_address, erc20_address=USDC_ADDRESS)
    assert deposit_success = TRUE
    return (TRUE)
end

################
# LP MINTING FUNCTIONS
################

func Liquidity_pool_mint_LP_for_WBTC{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount_to_deposit : Uint256, user_address : felt) -> (success : felt):
    alloc_locals

    let (local lp_per_wbtc : Uint256) = lp_token_offer_per_wbtc.read()
    let (local mint_amount : Uint256) = uint256_checked_mul(lp_per_wbtc, amount_to_deposit)

    Mintable_ERC.mint(contract_address=ZZ_TOKEN_ADDRESS, to=user_address, amount=mint_amount)
    return (TRUE)
end

func Liquidity_pool_mint_LP_for_ETH{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount_to_deposit : Uint256, user_address : felt) -> (success : felt):
    alloc_locals

    let (local lp_per_wbtc : Uint256) = lp_token_offer_per_eth.read()
    let (local mint_amount : Uint256) = uint256_checked_mul(lp_per_wbtc, amount_to_deposit)

    Mintable_ERC.mint(contract_address=ZZ_TOKEN_ADDRESS, to=user_address, amount=mint_amount)
    return (TRUE)
end

func Liquidity_pool_mint_LP_for_USDC{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount_to_deposit : Uint256, user_address : felt) -> (success : felt):
    alloc_locals

    let (local lp_per_wbtc : Uint256) = lp_token_offer_per_USDC.read()
    let (local mint_amount : Uint256) = uint256_checked_mul(lp_per_wbtc, amount_to_deposit)

    Mintable_ERC.mint(contract_address=ZZ_TOKEN_ADDRESS, to=user_address, amount=mint_amount)
    return (TRUE)
end

################
# LP MINTING FUNCTIONS
################

func Liquidity_pool_withdraw{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount_of_lp_to_deposit : Uint256, user_address : felt) -> (success : felt):
    alloc_locals

    # check that withdrawer has the required amount of lp tokens
    let (local user_lp_balance : Uint256) = Mintable_ERC.balanceOf(
        contract_address=ZZ_TOKEN_ADDRESS, account=user_address)

    with_attr error_message("not enough LP tokens"):
        let (local le : felt) = uint256_le(amount_of_lp_to_deposit, user_lp_balance)
        assert le = TRUE
    end

    # get total LP token supply
    let (local total_lp_supply : Uint256) = Mintable_ERC.totalSupply(
        contract_address=ZZ_TOKEN_ADDRESS)

    # get pool balance of each token
    let (local wbtc_balance : Uint256) = ERC.balanceOf(
        contract_address=WBTC_ADDRESS, account=user_address)

    let (local eth_balance : Uint256) = ERC.balanceOf(
        contract_address=ETH_ADDRESS, account=user_address)

    let (local usdc_balance : Uint256) = ERC.balanceOf(
        contract_address=USDC_ADDRESS, account=user_address)

    # calculate amount to transfer
    let (local wbtc_numerator : Uint256) = uint256_checked_mul(
        wbtc_balance * amount_of_lp_to_deposit)
    let (local wbtc_to_withdraw : Uint256) = uint256_checked_div_rem(
        wbtc_numerator, total_lp_supply)

    let (local eth_numerator : Uint256) = uint256_checked_mul(eth_balance * amount_of_lp_to_deposit)
    let (local eth_to_withdraw : Uint256) = uint256_checked_div_rem(eth_numerator, total_lp_supply)

    let (local usdc_numerator : Uint256) = uint256_checked_mul(
        usdc_balance * amount_of_lp_to_deposit)
    let (local usdc_to_withdraw : Uint256) = uint256_checked_div_rem(
        usdc_numerator, total_lp_supply)

    # transfer balances
    ERC.transfer(contract_address=WBTC_ADDRESS, recipient=user_address, amount=wbtc_to_withdraw)
    ERC.transfer(contract_address=ETH_ADDRESS, recipient=user_address, amount=eth_to_withdraw)
    ERC.transfer(contract_address=USDC_ADDRESS, recipient=user_address, amount=usdc_to_withdraw)

    # burn LP tokens
    Mintable_ERC.burn(
        contract_address=ZZ_TOKEN_ADDRESS, account=user_address, amount=amount_of_lp_to_deposit)
    return (TRUE)
end

################
# UTIL
################

func _update_weighted_average_timestamp{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        new_lp_minted : Uint256, user_address : felt) -> (success: bool):
        alloc_locals

        let (local current_balance: Uint256) = Mintable_ERC.balanceOf(contract_address=ZZ_TOKEN_ADDRESS, account=user_address)
        let (local current_average_time: felt) = user_weighted_average_time.read(user_address)
        let (local current_timestamp: felt) = get_block_timestamp()

# storage exchange_contract, LP_per_WSATOSHI, LP_per_WEI, LP_per_USDC_last_decimal, user_weighted_average_timestamp, zz_reward_per_LP
# funcs deposit_btc, deposit_eth, deposit_usdc, withdraw, view_ZZ_reward, claim_ZZ_reward, transfer_WBTC, transfer_ETH, transfer_USDC
#

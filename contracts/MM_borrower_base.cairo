%lang starknet

from openzeppelin.utils.constants import TRUE, FALSE
from openzeppelin.security.safemath import (
    uint256_checked_add, uint256_checked_mul, uint256_checked_sub_le, uint256_checked_div_rem)

from contracts.lib.mammoth_pool.contracts.lib.Pool_base import Pool_deposit, Pool_withdraw

# whitelisted market makers
@storage
func Approved_market_maker(mm_address : felt) -> (bool : felt):
end

# amount market makers have borrowed
@storage
func Market_maker_amount_borrowed(mm_address : felt) -> (amount : Uint256):
end

# total amount market makers have borrowed
@storage
func total_market_maker_borrow() -> (amount : Uint256):
end

namespace MarketMakerBorrow:
    func Only_approved_market_maker{
            syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(address : felt) -> (
            success : felt):
        alloc_locals

        let (local is_market_maker_approved : felt) = Approved_market_maker.read(address)
        with_attr error_message("MARKET MAKER NOT APPROVED TO BORROW"):
            assert is_market_maker_approved = TRUE
        end
        return (TRUE)
    end

    func borrow{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
            amount_to_borrow : Uint256, mm_address : felt, erc20_address : felt) -> (
            success : felt):
        alloc_locals
        Only_approved_market_maker()

        let (local withdraw_success : felt) = Pool_withdraw(
            amount=amount_to_borrow, address=user_address, erc20_address=erc20_address)

        with_attr error_message("WITHDRAW FAILED"):
            assert withdraw_success = TRUE
        end

        let (local current_amount_borrowed : Uint256) = Market_maker_amount_borrowed.read(
            mm_address)
        let (local current_total_borrowed : Uint256) = total_market_maker_borrow.read()

        local new_amount_borrowed = uint256_checked_add(current_amount_borrowed, amount_to_borrow)
        local new_total = uint256_checked_add(current_total_borrowed, amount_to_borrow)

        Market_maker_amount_borrowed.write(mm_address, new_amount_borrowed)
        total_market_maker_borrow.write(new_total)

        return (TRUE)
    end
    func repay{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
            amount_to_repay : Uint256, mm_address : felt, erc20_address : felt) -> (success : felt):
        alloc_locals

        let (local deposit_success : felt) = Pool_deposit(
            amount=amount_to_repay, address=user_address, erc20_address=erc20_address)

        with_attr error_message("DEPOSIT FAILED"):
            assert deposit_success = TRUE
        end

        let (local current_amount_borrowed : Uint256) = Market_maker_amount_borrowed.read(
            mm_address)
        let (local current_total_borrowed : Uint256) = total_market_maker_borrow.read()

        local new_amount_borrowed = uint256_checked_sub_le(current_amount_borrowed, amount_to_borrow)
        local new_total = uint256_checked_sub_le(current_total_borrowed, amount_to_borrow)

        Market_maker_amount_borrowed.write(mm_address, new_amount_borrowed)
        total_market_maker_borrow.write(new_total)

        return (TRUE)
    end
end

%lang starknet

from starkware.starknet.common.syscalls import get_block_timestamp
from starkware.cairo.common.bitwise import bitwise_and
from starkware.cairo.common.math import unsigned_div_rem

# base that implements functionality for a contract to alternate between different modes at a certain time delta

################
# STORAGE
################

# timestamp that contract began
@storage
func beginning_timestamp() -> (time : felt):
end

# time between switching modes (ex. 2 weeks)
@storage
func time_delta_modes() -> (delta : felt):
end

################
# FUNCTIONS
################

namespace TimeWindow:
    func get_current_mode{
            syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, bitwise_ptr : BitwiseBuiltin,
            range_check_ptr}() -> (mode : felt):
        alloc_locals

        # get current time and start time and time delta
        let (local current_time : felt) = get_block_timestamp()
        let (local start_time : felt) = beginning_timestamp.read()
        let (local time_delta : felt) = time_delta_modes.read()

        # shift time axis to 0
        local time_since_start : felt = current_time - start_time

        # divide time_since_start by time_delta
        let (local epoch : felt, _) = unsigned_div_rem(time_since_start, time_delta)

        # mode 0 if epoch is even and mode 1 if epoch is odd
        let (local mode : felt) = _even_or_odd(epoch)

        return (mode)
    end
end

################
# Utils
################

# helper function that returns 0 if even number and 1 if odd number (NOTE: we include 0 as even)
func _even_or_odd{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, bitwise_ptr : BitwiseBuiltin,
        range_check_ptr}(number : felt) -> (last_bit : felt):
    alloc_locals

    let (local last_binary_digit : felt) = bitwise_and(number, 1)

    if last_binary_digit == 0:
        return (0)
    else:
        return (1)
    end
end

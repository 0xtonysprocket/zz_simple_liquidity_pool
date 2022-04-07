%lang starknet

# imports ownable, Uint256, ZZ_liquidity_pool_base

from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_block_timestamp

from openzeppelin.token.erc20.interfaces.IERC20 import IERC20
from openzeppelin.access.ownable import Ownable_initializer, Ownable_only_owner, Ownable_get_owner

# setters set_exchange_contract, set_LP_per_WBTC, set_LP_per_ETH, set_LP_per_USDC,

# constructor: set owner, set zz_reward_per_LP, set exchange contract

# deposit functions: deposit_WBTC, deposit_ETH, deposit_USDC

# withdraw functions: withdraw

# transfer functions: transfer_for_trade

# require functions: require_only_exchange

# claim functions: claim_zz_reward

# getter: get_current_zz_reward, get_exchange_contract, get_LP_per_WBTC, get_LP_per_ETH, get_LP_per_USDC, get_zz_reward_per_LP, get_user_weighted_average_timestamp

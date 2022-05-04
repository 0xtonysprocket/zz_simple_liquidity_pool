%lang starknet

# Rate for senior holders ZZ token reward per LP token held per 3600 seconds
@storage
func senior_zz_token_rate() -> (reward : Uint256):
end

# Rate for junior holders ZZ token reward per LP token held per 3600 seconds
@storage
func junior_zz_token_rate() -> (reward : Uint256):
end

# ZZ token reward per LP token held per 3600 seconds
@storage
func user_weighted_average_timestamp(user_account : felt) -> (timestamp : felt):
end

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

pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract mUST is ERC20, ERC20Burnable, Ownable {
	address[] public vaults;

	event vaultAdded(address _vault);
	event vaultDeleted(address _vault);

	modifier onlyVault() { 
		require(isVault(msg.sender), "mUST: msg.sender is not Vault");
		_;
	}

	constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

	function addVault(address _vault) onlyOwner public {
		// Audit: Vault 주소가 영주소인 경우 예외처리 필요
		require(_vault != address(0), "mUST: Vault address cannot be zero");
		// Audit: Vault 주소가 이미 존재하는 경우 예외처리 필요
		require(!isVault(_vault), "mUST: Vault already exists");
		vaults.push(_vault);
		emit vaultAdded(_vault);
	}

	function deleteVault(address _vault) onlyOwner public {
		// Audit: Vault 주소가 영주소인 경우 예외처리 필요
		require(_vault != address(0), "mUST: Vault address cannot be zero");
		// Audit: Vault 주소가 존재하지 않는 경우 예외처리 필요	
		require(isVault(_vault), "mUST: Vault does not exist");
		// Audit: Vault가 하나도 없는 경우 예외처리 필요
		require(vaults.length > 0, "mUST: No vaults to delete");
		
		for(uint i=0; i<vaults.length; i++) {
			if(vaults[i] == _vault) { 
				vaults[i] = vaults[vaults.length - 1]; 
				break;
			}
		}
		vaults.pop();
		emit vaultDeleted(_vault);
	}

	function mint(uint256 amount) onlyVault public {
		// Audit: amount가 0인 경우 이후 로직을 실행할 필요가 없기 때문에 0인 경우 예외처리 필요
		require(amount > 0, "mUST: Amount must be greater than zero");
		_mint(msg.sender, amount);
	}

	function burn(uint256 amount) onlyVault public override {
		// Audit: amount가 0인 경우 이후 로직을 실행할 필요가 없기 때문에 0인 경우 예외처리 필요
		require(amount > 0, "mUST: Amount must be greater than zero");
		super.burn(amount);
	}

	function burnFrom(address account, uint256 amount) onlyVault public override {
		// Audit: account가 영주소인 경우 예외처리 필요
		require(account != address(0), "mUST: Account cannot be zero address");
		// Audit: amount가 0인 경우 이후 로직을 실행할 필요가 없기 때문에 0인 경우 예외처리 필요
		require(amount > 0, "mUST: Amount must be greater than zero");
        super.burnFrom(account, amount);
	}

	function isVault(address _vault) view public returns (bool) {
		for(uint i=0; i<vaults.length; i++) {
			if(vaults[i] == _vault) return true;
		}
		return false;
	}
}

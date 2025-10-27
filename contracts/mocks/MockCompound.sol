pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract MockCompound is ERC20, ERC20Burnable {
	constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

	function redeemUnderlying(uint256 amount) public returns (uint256) {
		// Audit: amount가 0인 경우 이후 로직을 실행할 필요가 없기 때문에 0인 경우 예외처리 필요
		require(amount > 0, "MockCompound: amount must be greater than zero");
		return 0;
	}

	function mint(uint256 amount) public returns (uint256) {
		// Audit: amount가 0인 경우 이후 로직을 실행할 필요가 없기 때문에 0인 경우 예외처리 필요
		require(amount > 0, "MockCompound: amount must be greater than zero");
		_mint(msg.sender, amount);
		return 0;
	}
}
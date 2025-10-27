pragma solidity 0.8.16;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Oracle {
	IERC20 mUST;

	constructor(address _mUST) {
		mUST = IERC20(_mUST);
	}

	function calcMustardPrice(IERC20 token, address pair) public view returns (uint256) {
		// Audit: pair 주소가 영주소인 경우, 유동성이 불충분한 경우 예외처리 필요
		require(pair != address(0), "Oracle: Invalid pair address");
		require(mUST.balanceOf(pair) > 1e18, "Oracle: Insufficient mUST liquidity");
		require(token.balanceOf(pair) > 0, "Oracle: Insufficient token liquidity");

		// Audit: balanceOf 호출을 한 번만 하도록 최적화
		uint256 mUSTBalance = mUST.balanceOf(pair);
		uint256 tokenBalance = token.balanceOf(pair);
		
		return mUSTBalance * tokenBalance / (mUSTBalance - 1e18) - tokenBalance;
	}
}
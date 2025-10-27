pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IFlashloanReceiver {
	function flashloanReceived (address token, uint256 amount) external;
}

contract MockPair is ReentrancyGuard {
	address public tokenA;
	address public tokenB;

	uint256 tokenAmountA;
	uint256 tokenAmountB;
	uint256 K;

	constructor(address _tokenA, address _tokenB) {
		// Audit: tokenA, tokenB 주소가 영주소인 경우 예외처리 필요
		require(_tokenA != address(0), "MockPair: tokenA cannot be zero address");
		require(_tokenB != address(0), "MockPair: tokenB cannot be zero address");
		// Audit: tokenA, tokenB가 같은 주소인 경우 예외처리 필요
		require(_tokenA != _tokenB, "MockPair: tokenA and tokenB must be different");
		tokenA = _tokenA;
		tokenB = _tokenB;
	}

	function flashloan(address token, uint256 amount, address to) public nonReentrant {
		// Audit: token, amount, to가 0인 경우 이후 로직을 실행할 필요가 없기 때문에 0인 경우 예외처리 필요
		require(token != address(0), "MockPair: token cannot be zero address");
		require(amount > 0, "MockPair: amount must be greater than zero");
		require(to != address(0), "MockPair: to cannot be zero address");
		// Audit: token이 tokenA 또는 tokenB가 아닌 경우 예외처리 필요
		require(token == tokenA || token == tokenB, "MockPair: Not target pair");
		
		tokenAmountA = IERC20(tokenA).balanceOf(address(this));
		tokenAmountB = IERC20(tokenB).balanceOf(address(this));
		K = tokenAmountA * tokenAmountB;
		IERC20(token).transfer(to, amount);
		IFlashloanReceiver(to).flashloanReceived(token, amount);
		uint256 before = token==tokenA?tokenAmountA:tokenAmountB;
		require(IERC20(token).balanceOf(address(this)) >= before, "MockPair: Flashloan failed");
	}

	function swap(address token, uint256 amount) public {
		// Audit: token, amount가 0인 경우 이후 로직을 실행할 필요가 없기 때문에 0인 경우 예외처리 필요
		require(token != address(0), "MockPair: token cannot be zero address");
		require(amount > 0, "MockPair: amount must be greater than zero");
		// Audit: token이 tokenA 또는 tokenB가 아닌 경우 예외처리 필요
		require(token == tokenA || token == tokenB, "MockPair: Not target pair");
		
		if(token == tokenA) {
			uint256 swapAmt = K / (tokenAmountA - amount) - tokenAmountB;
			tokenAmountA += amount;
			tokenAmountB -= swapAmt;
			safeTransferFrom(token, msg.sender, address(this), amount);
			IERC20(tokenB).transfer(msg.sender, swapAmt);
		}
		else {
			uint256 swapAmt = K / (tokenAmountB - amount) - tokenAmountA;
			tokenAmountB += amount;
			tokenAmountA -= swapAmt;
			IERC20(token).transferFrom(msg.sender, address(this), amount);
			IERC20(tokenA).transfer(msg.sender, swapAmt);
		}
	}

	function safeTransferFrom(address token, address from, address to, uint256 amount) private {
		// Audit: token, from, to, amount가 0인 경우 이후 로직을 실행할 필요가 없기 때문에 0인 경우 예외처리 필요
		require(token != address(0), "MockPair: token cannot be zero address");
		require(from != address(0), "MockPair: from cannot be zero address");
		require(to != address(0), "MockPair: to cannot be zero address");
		require(amount > 0, "MockPair: amount must be greater than zero");
		
		(bool success, bytes memory data) = token.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", from, to, amount)
        );
        // Audit: Vault 컨트랙트가 아닌 MockPair 컨트랙트에서 발생한 오류이기 때문에 수정
		require(success, "MockPair: safeTransferFrom is not successful");
	}
}
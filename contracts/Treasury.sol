pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface ImUST {
	function isVault(address _vault) view external returns (bool);
}

interface IStrategy {
	function setCToken(address _ctoken) external;
	function getTokens(uint256 amount) external;
	function execute(uint256 amount) external payable;
}

interface IWETH {
	function withdraw(uint wad) external;
}

contract Treasury is Ownable, NonReentrancyGuard {

	address public mUST;
	address public WETH;

	modifier onlyVault() { 
		require(ImUST(mUST).isVault(msg.sender), "mUST: msg.sender is not Vault");
		_;
	}

	mapping(address => address) public strategies;

	event strategyModified(address _strategy, address _baseToken);
	event strategyExecuted(address _strategy, uint256 _amount);

	constructor(address _mUST, address _WETH) {
		// Audit: mUST, WETH 주소가 영주소인 경우 예외처리 필요
		require(_mUST != address(0), "Treasury: mUST address cannot be zero");
		require(_WETH != address(0), "Treasury: WETH address cannot be zero");
		mUST = _mUST;
		WETH = _WETH;
	}

	function modifyStrategy(address _baseToken, address _strategy) onlyOwner public {
		// Audit: baseToken, strategy 주소가 영주소인 경우 예외처리 필요
		require(_baseToken != address(0), "Treasury: baseToken address cannot be zero");
		require(_strategy != address(0), "Treasury: strategy address cannot be zero");
		strategies[_baseToken] = _strategy;
		emit strategyModified(_strategy, _baseToken);
	}

	function executeStrategy(address _baseToken, uint256 _amount) public payable onlyOwner {
		// Audit: baseToken, amount가 0인 경우 이후 로직을 실행할 필요가 없기 때문에 0인 경우 예외처리 필요
		require(_baseToken != address(0), "Treasury: baseToken address cannot be zero");
		require(_amount > 0, "Treasury: amount must be greater than zero");
		// Audit: strategy가 설정되어 있는지 확인 필요
		require(strategies[_baseToken] != address(0), "Treasury: strategy not set for this token");
		
		_safeTransfer(_baseToken, strategies[_baseToken], _amount);
		(bool success, bytes memory data) = strategies[_baseToken].call{ value: msg.value }(
            abi.encodeWithSignature("execute(uint256)", _amount)
        );
        require(success, "Treasury: Strategy execution is not successful");
	}

	// 자금 회수 - baseToken을 Treasury에서 사용자에게 전송하는 함수
	function getTokenTo(address _baseToken, uint256 _amount, address _to) onlyVault public payable {
		// Audit: baseToken, amount, to가 0인 경우 이후 로직을 실행할 필요가 없기 때문에 0인 경우 예외처리 필요
		require(_baseToken != address(0), "Treasury: baseToken address cannot be zero");
		require(_amount > 0, "Treasury: amount must be greater than zero");
		require(_to != address(0), "Treasury: to address cannot be zero");
		
		uint256 curBal = IERC20(_baseToken).balanceOf(address(this));
		if (curBal >= 0 && curBal < _amount) { IStrategy(strategies[_baseToken]).getTokens(_amount - curBal); }
		_safeTransfer(_baseToken, _to, _amount);
	}

	// Audit: safeTransfer 함수는 외부에서 호출하지 않는 함수이기 때문에 함수명 앞에 _를 붙이는 것이 좋음
	function _safeTransfer(address token, address to, uint256 amount) private {
		// Audit: token, to, amount가 0인 경우 이후 로직을 실행할 필요가 없기 때문에 0인 경우 예외처리 필요
		require(token != address(0), "Treasury: token address cannot be zero");
		require(to != address(0), "Treasury: to address cannot be zero");
		require(amount > 0, "Treasury: amount must be greater than zero");
		
		(bool success, bytes memory data) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );
        require(success, "Treasury: _safeTransfer is not successful");
	}

	// 자금 회수 - ETH을 Treasury에서 사용자에게 전송하는 함수
	function getETHTo(uint256 _amount, address payable _to) onlyVault public nonReentrant {
		// Audit: amount, to가 0인 경우 이후 로직을 실행할 필요가 없기 때문에 0인 경우 예외처리 필요
		require(_amount > 0, "Treasury: amount must be greater than zero");
		require(_to != address(0), "Treasury: to address cannot be zero");
		
		uint256 curBal = IERC20(WETH).balanceOf(address(this));
		if (curBal >= 0 && curBal < _amount) { IStrategy(strategies[WETH]).getTokens(_amount - curBal); }
		IWETH(WETH).withdraw(_amount);
		_to.call{value: address(this).balance}("");
	}

	receive() external payable {}

	fallback() external payable {}
}
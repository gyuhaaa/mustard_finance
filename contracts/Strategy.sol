import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";	// Audit: Ownable 추가
pragma solidity 0.8.16;
import "hardhat/console.sol";

interface ICtoken {
	function redeemUnderlying(uint256 amount) external returns (uint256);
	function mint(uint256 amount) external returns (uint256);
}

// Audit: Strategy 컨트랙트에 Ownable 추가
contract Strategy is Ownable {
	ICtoken public ctoken;
	address public baseToken;
	address public treasury;

	constructor(address _ctoken, address _baseToken, address _treasury) {
		// Audit: cToken, baseToken, treasury 주소가 영주소인 경우 예외처리 필요
		require(_ctoken != address(0), "Strategy: cToken address cannot be zero");
		require(_baseToken != address(0), "Strategy: baseToken address cannot be zero");
		require(_treasury != address(0), "Strategy: treasury address cannot be zero");
		
		ctoken = ICtoken(_ctoken);
		baseToken = _baseToken;
		treasury = _treasury;
	}

	// Audit: Treasury 컨트랙트만 이 함수를 호출할 수 있도록 제한
	modifier onlyTreasury() {
		require(msg.sender == treasury, "Strategy: Only Treasury can call");
		_;
	}

	// Audit: Owner만 이 함수를 호출할 수 있도록 제한
	function setCToken(address _ctoken) public onlyOwner {
		// Audit: cToken 주소가 영주소인 경우 예외처리 필요
		require(_ctoken != address(0), "Strategy: cToken address cannot be zero");
		ctoken = ICtoken(_ctoken);
	}

	// 자금 회수 - ctoken을 baseToken으로 회수하는 함수. Compound에서 자금 인출해서 Treasury로 전송.
	// Audit: Treasury 컨트랙트만 이 함수를 호출할 수 있도록 제한
	function getTokens(uint256 amount) public onlyTreasury {
		// Audit: amount가 0인 경우 이후 로직을 실행할 필요가 없기 때문에 0인 경우 예외처리 필요
		require(amount > 0, "Strategy: Amount must be greater than zero");
		// Audit: redeemUnderlying 함수 실행 결과를 확인하여 실패 시 예외처리
		require(ctoken.redeemUnderlying(amount) == 0, "Strategy: Redeem failed");
		IERC20(baseToken).transfer(treasury, amount);
	}

	// 자금 투자 - baseToken을 ctoken으로 투자하는 함수.
	// Audit: Treasury 컨트랙트만 이 함수를 호출할 수 있도록 제한
	function execute(uint256 amount) public payable onlyTreasury {
		// Audit: amount가 0인 경우 이후 로직을 실행할 필요가 없기 때문에 0인 경우 예외처리 필요
		require(amount > 0, "Strategy: Amount must be greater than zero");
		IERC20(baseToken).approve(address(ctoken), amount); 
		safeApprove(baseToken, address(ctoken), amount);
		// Audit: 주석 해제. mint 함수 실행 결과를 확인하여 실패 시 예외처리
		require(ctoken.mint(amount) == 0, "Strategy: Mint failed"); 
	}

	function safeApprove(address token, address to, uint256 amount) private {
		// Audit: token, to, amount가 0인 경우 이후 로직을 실행할 필요가 없기 때문에 0인 경우 예외처리 필요
		require(token != address(0), "Strategy: Token address cannot be zero");
		require(to != address(0), "Strategy: To address cannot be zero");
		require(amount > 0, "Strategy: Amount must be greater than zero");
		
		(bool success, bytes memory data) = token.call(
            abi.encodeWithSignature("approve(address,uint256)", to, amount)
        );
        require(success, "Strategy: safeApprove is not successful");
	}

	receive() external payable {}

	fallback() external payable {}
}
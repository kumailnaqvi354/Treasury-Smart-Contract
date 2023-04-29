// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Interfaces/IUniswap.sol";
import "./Interfaces/IERC721.sol";
import "./Interfaces/ISushiswapV2Router.sol";
import "./Interfaces/ITreasury.sol";

contract Treasury is Ownable, ERC20, IERC721Receiver, ITreasury {
    int24 private constant MIN_TICK = -887272;
    int24 private constant MAX_TICK = -MIN_TICK;
    int24 private constant TICK_SPACING = 60;

    address public constant USDT = 0xC2C527C0CACF457746Bd31B2a698Fe89de2b6d49;
    address public constant DAI = 0x11fE4B6AE13d2a6055C8D9cF65c55bac32B5d844;

    address private constant FACTORY =
        0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address private constant ROUTER =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    uint256[] public dividendRatio;
    uint256 UniswapPositionTokenId;
    uint256 totalSupplyForSushiSwap;
    uint256 feeTier = 3000;

    INonfungiblePositionManager public nonfungiblePositionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    event LiquidityMint(
        uint tokenId,
        uint128 liquidity,
        uint amount0,
        uint amount1
    );
    event withdrawLiquidity(uint amount0, uint amount1);

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _tier
    ) ERC20(_name, _symbol) {
        feeTier = _tier;
    }

    function onERC721Received(
        address operator,
        address from,
        uint tokenId,
        bytes calldata
    ) external returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}

    fallback() external payable {}

    // @notice Deposit stable token to the Treasure Tokens
    // @notice params The parameters are necessary for the Liquidity Provision and K value Calculation
    function depositTokens(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1
    ) external virtual override {
        require(
            amount0 > 0 && amount1 > 0,
            "Amount should be greater than zero"
        );
        IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        IERC20(token1).transferFrom(msg.sender, address(this), amount1);
        uint256 k;
        unchecked {
            k = amount0 * amount1;
        }
        _mint(msg.sender, k);
    }

    // @notice Only Owner of contract can Call
    // @notice add Liquidity from treasury to protocols
    // @notice given USDT and DAI tokens are used
    function addLiquidityToProtocols() external virtual override onlyOwner {
        uint256 ratioA = IERC20(USDT).balanceOf(address(this)) / 2;
        uint256 ratioB = IERC20(DAI).balanceOf(address(this)) / 2;

        addLiquidityOnSushiswap(USDT, DAI, ratioA, ratioB);
        createPositionOnUniswap(
            IERC20(USDT).balanceOf(address(this)),
            IERC20(DAI).balanceOf(address(this))
        );
    }

    // @notice Calculate max APY per given tokens Tokens
    function calculateAPY(address _caller)
        external
        view
        virtual
        override
        returns (uint256, uint256)
    {
        uint maxFee0 = calculateAPYForUniswap(_caller);
        uint maxFee1 = calculateAPYForSushiswap(_caller);
        return (maxFee0, maxFee1);
    }

    // @notice Withdraw liquidity from liquidity pool
    function withdrawLiquidityFromPool() external virtual override {
        removeUniswapLiquidity(msg.sender);
        removerSushiSwapLiquidity(msg.sender);
    }

    // @notice Withdraw liquidity from liquidity pool
    function setRatio(uint256[] calldata _value) external virtual override onlyOwner{
        require(_value.length > 0);
        dividendRatio = _value;
    } 

    // @notice mint new postition on uniswap by given tokens
    // @notice returns K value, for the new position
    function createPositionOnUniswap(uint256 _amount0, uint256 _amount1)
        internal
        returns (uint256)
    {
        IERC20(USDT).approve(
            address(nonfungiblePositionManager),
            _balanceOf(USDT)
        );
        IERC20(DAI).approve(
            address(nonfungiblePositionManager),
            _balanceOf(DAI)
        );

        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: USDT,
                token1: DAI,
                fee: 3000,
                tickLower: (MIN_TICK / TICK_SPACING) * TICK_SPACING,
                tickUpper: (MAX_TICK / TICK_SPACING) * TICK_SPACING,
                amount0Desired: _amount0,
                amount1Desired: _amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            });

        (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        ) = nonfungiblePositionManager.mint(params);
        UniswapPositionTokenId = tokenId;

        emit LiquidityMint(tokenId, liquidity, amount0, amount1);
        return liquidity;
    }

    // @notice Add liquidity On Sushiswap
    // @notice takes 4 inputs, TOKEN0, Tokens1, and Amount0, Amount1
    function addLiquidityOnSushiswap(
        address _tokenA,
        address _tokenB,
        uint _amountA,
        uint _amountB
    ) internal returns (uint256, uint256) {
        IERC20(USDT).approve(ROUTER, _amountA);
        IERC20(DAI).approve(ROUTER, _amountB);

        (uint amountA, uint amountB, uint liquidity) = ISushiswapV2Router(
            ROUTER
        ).addLiquidity(
                _tokenA,
                _tokenB,
                _amountA,
                _amountB,
                1,
                1,
                msg.sender,
                block.timestamp
            );

        totalSupplyForSushiSwap += liquidity;
        return (amountA, amountB);
    }

    // @notice calculate max apy for given user on Uniswap
    function calculateAPYForUniswap(address _caller)
        internal
        view
        returns (uint256)
    {
        uint256 maxAPY = (balanceOf(_caller) / totalSupply()) * feeTier;
        return maxAPY;
    }

    // @notice calculate max apy for given user on Sushiswap
    function calculateAPYForSushiswap(address _caller)
        internal
        view
        returns (uint256)
    {
        address pair = ISushiswapV2Factory(FACTORY).getPair(USDT, DAI);
        uint256 maxAPY = (IERC20(pair).balanceOf(_caller) /
            totalSupplyForSushiSwap) * 10000;
        return maxAPY;
    }

    function _balanceOf(address token) internal returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    // @notice Remove Liquidity for given user
    // @notice calculate ratio from the pool liquidity
    // @notice Burn LPtoken and transfer liquidity tokens to user
    function removerSushiSwapLiquidity(address _caller)
        internal
        returns (uint, uint)
    {
        address pair = ISushiswapV2Factory(FACTORY).getPair(USDT, DAI);

        uint liquidity = IERC20(pair).balanceOf(_caller);
        IERC20(pair).approve(ROUTER, liquidity);
        uint256 userShare = (liquidity * 1e18) / totalSupplyForSushiSwap;
        (uint amountA, uint amountB) = ISushiswapV2Router(ROUTER)
            .removeLiquidity(
                USDT,
                DAI,
                userShare,
                1,
                1,
                _caller,
                block.timestamp
            );
        totalSupplyForSushiSwap -= userShare;
        return (amountA, amountB);
    }

    // @notice Remove Liquidity for given user
    // @notice calculate ratio from the pool liquidity
    // @notice Burn LPtoken and transfer liquidity tokens to user
    function removeUniswapLiquidity(address _caller) internal {
        uint256 _lpBalance = balanceOf(msg.sender);
        uint128 userShare;
        unchecked {
            userShare = (uint128(_lpBalance) * 1e18) / uint128(totalSupply());
        }
        INonfungiblePositionManager.DecreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .DecreaseLiquidityParams({
                    tokenId: UniswapPositionTokenId,
                    liquidity: userShare,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        (uint256 amount0, uint256 amount1) = nonfungiblePositionManager
            .decreaseLiquidity(params);
        _burn(_caller, userShare);
        emit withdrawLiquidity(amount0, amount1);
    }
}

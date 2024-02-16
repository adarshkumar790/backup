// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../Storage/MarketStorageModule.sol";
import "../Interfaces/IMarketStorageModule.sol";
import "../Interfaces/IAssetManager.sol";
import "./AssetLib.sol";

/**
 * @title Asset Manager for FXDX 
 * @notice Manages information related to different asset classes.
 * @dev The contract provides methods to check asset existence, liquidity, and prices across various sources.
 */
contract AssetManager is Ownable, IAssetManager {
    
   using AssetLib for AssetLib.AssetProps;
    using AssetLib for AssetLib.TimedMarketAssetProps;
    using MarketPoolProps for MarketPoolProps.Props;

    IMarketStorageModule private marketStorageModuleInstance;

    struct AssetPropsUpdateOperation {
        uint256 assetId;
        AssetLib.AssetProps newValues;
        bool updateMinLiquidityRequiredForExecution;
        bool updateIsWhitelisted;
        bool updateChainIdAllowed;
        bool updateAssetAddressByChainId;
        bool updateTOKEN_DECIMALS_PRECISION;
        bool updateTOKEN_PRICE_PRECISION;
        bool updateIsIsolatedPoolStatus;
        bool updateIsSharedPoolStatus;
        bool updateIsDecentralisedSourceEnabled;  
        bool updateIsCentralisedSourceEnabled;
        bool updateIsShortable; 
        bool updateIsStable; 
        bool updateIsLongable; 
        bool updateIsCollateral; 
        bool updateIsReference;
        bool updateIsSwapEnabled; 
        bool updateIsMarginTradingEnabled; 
        bool updateIsLimitOrderBookEnabled; 
        bool updateIsExternalLiquidityEnabled;
        bool update_maxLeverageFactor; 
        bool update_positionSizeReserveFactor; 
        bool update_MAXIMUM_POSITION_SIZE_PER_MARKET; 
        bool update_MAX_POSITION_PNL_FACTOR; 
        bool update_MAX_GLOBAL_PNL_FACTOR; 
    }

    struct TimedMarketAssetPropsUpdateOperation {
        uint256 assetId;
        AssetLib.TimedMarketAssetProps newValues;
        bool updateReferenceAsset;
        bool updateMarketOpenTimeStamp;
        bool updateMarketOpenDurationsinSeconds;
    }
   
    mapping(uint256 => AssetLib.AssetProps) public cryptoAssets;
    mapping(uint256 => AssetLib.TimedMarketAssetProps) public timedMarketAssets;
    mapping(uint256 => AssetLib.AssetRequirements) public assetRequirements;
    mapping(uint256 => AssetLib.SpreadData) public spreadData;
    mapping(uint256 => AssetLib.DeviationData) public deviationData;
    mapping(address => uint256) public tokenAddressToAssetId;
    mapping(uint256 => mapping(uint256 => address)) public assetIdToChainIdToAddress; 
    mapping(address => uint256) assetManagerAddressToChainId;

    uint256 public assetCount;
    uint256[] public allowedChainIds;

    event CryptoAssetAdded(uint256 indexed assetId);
    event CryptoAssetUpdated(uint256 indexed assetId, uint256[] minLiquidityRequiredForExecution, bool isShortable);
    event TimedMarketAssetAdded(uint256 indexed assetId);
    event TimedMarketAssetUpdated(uint256 indexed assetId, uint256 minLiquidityRequiredForExecution, string referenceAsset, uint256 marketOpenTime, uint256 marketCloseTime);
    //   event AssetTradePropsUpdated(
    //     uint256 indexed assetId,
    //     bool isReference,
    //     bool isLongable,
    //     bool isShortable,
    //     bool isStable,
    //     bool isCollateral
    // );
    event TradePropsShortableUpdated(uint256 indexed assetId, bool isShortable);
    event TradePropsStableUpdated(uint256 indexed assetId, bool isStable );
    event TradePropsLongableUpdated(uint256 indexed assetId, bool isLongable);
    event TradePropsCollateralUpdated(uint256 indexed assetId, bool isCollateral);
    event TradePropsReferenceUpdated(uint256 indexed assetId, bool isReference);

    event AssetRiskFactorsUpdated(
    uint256 indexed assetId,
    uint256 maxLeverageFactor,
    uint256 positionSizeReserveFactor,
    bool maxPosSizePerMarket,
    uint256 maxPosPnlFactor,
    uint256 maxGlobalPnlFactor
    );

    event TimedMarketAssetAdded(
    uint256 indexed assetId,
    uint256 maxLeverageFactor,
    uint256 positionSizeReserveFactor,
    bool maxPosSizePerMarket,
    uint256 maxPosPnlFactor,
    uint256 maxGlobalPnlFactor
    );

    event TimedMarketAssetMarketTimingsUpdated(
    uint256 indexed assetId,
    uint256 marketOpenTimestamp,
    uint256 marketOpenDuration
    );

    event AssetUpdated(
       uint256 indexed assetId,
       uint256 minLiquidityRequiredForExecution,
       bool isWhitelisted,
       uint256 chainIdAllowed,
       address assetAddressByChainId,
       uint256 TOKEN_DECIMALS_PRECISION,
       uint256 TOKEN_PRICE_PRECISION,
       bool isIsolatedPoolAllowed,
       bool isSharedPoolAllowed,
       bool isDecentralisedSourceEnabled,
       bool isCentralisedSourceEnabled,
       bool isShortable,
       bool isStable,
       bool isLongable,
       bool isCollateral,
       bool isReference,
       bool isSwapEnabled,
       bool isMarginTradingEnabled,
       bool isLimitOrderBookEnabled,
       bool isExternalLiquidityEnabled,
       uint256 maxLeverageFactor,
       uint256 positionSizeReserveFactor,
       bool MAXIMUM_POSITION_SIZE_PER_MARKET,
       uint256 MAX_POSITION_PNL_FACTOR,
       uint256 MAX_GLOBAL_PNL_FACTOR
    );

    event TimedMarketAssetUpdated(
      uint256 indexed assetId,
      uint256 minLiquidityRequiredForExecution,
      address referenceAsset,
      uint256 marketOpenTimeStamp,
      uint256 marketOpenDurationsinSeconds
    );

    event CryptoAssetAdded(
    uint256 indexed assetId,
    bool isWhitelisted,
    address assetAddressByChainId,
    bool isDecentralisedSourceEnabled,
    bool isCentralisedSourceEnabled,
    bool isShortable,
    bool isStable,
    bool isLongable,
    bool isCollateral,
    bool isSwapEnabled,
    bool isMarginTradingEnabled
    );
    event CryptoAssetUpdated(
    uint256 indexed assetId,
    uint256[] minLiquidityRequiredForExecution,
    bool isShortable
    );

    event WhitelistedStatusUpdated(uint256 indexed assetId, bool isWhitelisted);
    event AssetAddressByChainIdupdated(uint256 indexed assetId, address assetAddresses);
    event AssetListingStageUpdated(
    uint256 indexed assetId,
    bool isIsolatedPoolAllowed,
    bool isSharedPoolAllowed
    );
    event OracleSourceStatusUpdated(
    uint256 indexed assetId,
    bool isDecentralisedSourceEnabled,
    bool isCentralisedSourceEnabled
    );




    // event AssetRiskFactorsUpdated(
    //     uint256 indexed assetId,
    //     uint256 maxLeverageFactor,
    //     uint256 positionSizeReserveFactor,
    //     bool maxPosSizePerMarket,
    //     uint256 maxPosPnlFactor,
    //     uint256 maxGlobalPnlFactor
    // );


    constructor(address _marketStorageModule, uint256[] memory _chainIds) Ownable(msg.sender){
        marketStorageModuleInstance = IMarketStorageModule(_marketStorageModule);
        allowedChainIds = _chainIds;   
    }
    function addCryptoAsset(
            AssetLib.AssetProps memory cryptoProps
        ) external  onlyOwner {
            // validation: check whether assetManager chain id is same as chain id passed in params
            // 
            assetCount++;
            cryptoProps.id = assetCount;
            uint256 assetId = cryptoProps.id;
            require(!cryptoAssets[assetId].isWhitelisted, "Asset already exists");

            cryptoAssets[assetId] = cryptoProps;
            // tokenAddressToAssetId[cryptoProps]
        emit CryptoAssetAdded(
          assetId,
          cryptoProps.isWhitelisted,
          cryptoProps.assetAddressByChainId,
          cryptoProps.isDecentralisedSourceEnabled,
          cryptoProps.isCentralisedSourceEnabled,
          cryptoProps.tradeProps.isShortable,
          cryptoProps.tradeProps.isStable,
          cryptoProps.tradeProps.isLongable,
          cryptoProps.tradeProps.isCollateral,
          cryptoProps.marketProps.isSwapEnabled,
          cryptoProps.marketProps.isMarginTradingEnabled
        );
    } 


    function updateMinLiquidity(uint256 _assetId, uint256[] memory _minLiquidityRequiredForExecution) external onlyOwner {
        cryptoAssets[_assetId].minLiquidityRequiredForExecution = _minLiquidityRequiredForExecution;
        emit CryptoAssetUpdated(_assetId, _minLiquidityRequiredForExecution, cryptoAssets[_assetId].tradeProps.isShortable);

    }

    function updateWhitelistedStatus(uint256 _assetId, bool _isWhitelisted) external onlyOwner {
        cryptoAssets[_assetId].isWhitelisted = _isWhitelisted; // 0.00005612 ETH gas --> $0.13 USD gas
        emit WhitelistedStatusUpdated(_assetId, _isWhitelisted);
    }

    function updateAssetAddressByChainId(uint256 _assetId, address[] memory _assetAddresses) external onlyOwner {
        cryptoAssets[_assetId].assetAddressByChainId = _assetAddresses;
        emit AssetAddressByChainIdupdated(_assetId, _assetAddresses);
    }

    function updateAssetListingStage(uint256 _assetId, bool _isIsolatedPoolStatus, bool _isSharedPoolStatus) external onlyOwner {
        cryptoAssets[_assetId].isIsolatedPoolAllowed = _isIsolatedPoolStatus;
        cryptoAssets[_assetId].isSharedPoolAllowed = _isSharedPoolStatus;
       emit AssetListingStageUpdated(_assetId, _isIsolatedPoolStatus, _isSharedPoolStatus);
    }

    function updateOracleSourceStatus(uint256 _assetId, bool _isDecentralisedEnabled, bool _isCentralisedEnabled) external onlyOwner() {
        cryptoAssets[_assetId].isDecentralisedSourceEnabled = _isDecentralisedEnabled;
        cryptoAssets[_assetId].isCentralisedSourceEnabled = _isCentralisedEnabled;

        emit OracleSourceStatusUpdated(_assetId, _isDecentralisedEnabled, _isCentralisedEnabled);
    }

    function updateTradePropsShortable(uint256 _assetId, bool _isShortable) external onlyOwner() {
        cryptoAssets[_assetId].tradeProps.isShortable = _isShortable;
          emit TradePropsShortableUpdated(_assetId, _isShortable);
    }
    function updateTradePropsStable(uint256 _assetId, bool _isStable) external  onlyOwner() {
        cryptoAssets[_assetId].tradeProps.isStable = _isStable;
         emit TradePropsStableUpdated(_assetId,_isStable);
    }

    function updateTradePropsLongable(uint256 _assetId, bool _isLongable) external onlyOwner() {
        cryptoAssets[_assetId].tradeProps.isLongable = _isLongable;
        emit TradePropsLongableUpdated(_assetId, _isLongable);
    }
    function updateTradePropsCollateral(uint256 _assetId, bool _isCollateral) external onlyOwner() {
        cryptoAssets[_assetId].tradeProps.isCollateral = _isCollateral;
        emit TradePropsCollateralUpdated(_assetId, _isCollateral);
    }

    function updateTradePropsReference(uint256 _assetId, bool _isReference) external onlyOwner() {
        cryptoAssets[_assetId].tradeProps.isReference = _isReference;
        emit TradePropsReferenceUpdated(_assetId, _isReference);
    }

    function updateAssetRiskFactors(
            uint256 _assetId, 
            uint256 _maxLeverageFactor,
            uint256 _positionSizeReserveFactor,
            bool _maxPosSizePerMarket,
            uint256 _maxPosPnlFactor,
            uint256 _maxGlobalPnlFactor
        ) external onlyOwner {
            cryptoAssets[_assetId].riskProps.maxLeverageFactor = _maxLeverageFactor;
            cryptoAssets[_assetId].riskProps.positionSizeReserveFactor = _positionSizeReserveFactor;
            cryptoAssets[_assetId].riskProps.MAXIMUM_POSITION_SIZE_PER_MARKET = _maxPosSizePerMarket;
            cryptoAssets[_assetId].riskProps.MAX_POSITION_PNL_FACTOR = _maxPosPnlFactor;
            cryptoAssets[_assetId].riskProps.MAX_GLOBAL_PNL_FACTOR = _maxGlobalPnlFactor;

           emit AssetRiskFactorsUpdated(
            _assetId,
            _maxLeverageFactor,
            _positionSizeReserveFactor,
            _maxPosSizePerMarket,
            _maxPosPnlFactor,
            _maxGlobalPnlFactor
           );
        }


    function addTimedMarketAsset( // forex and commodity
            AssetLib.TimedMarketAssetProps memory forexOrCommodityProps
        ) external onlyOwner {
            uint256 assetId = forexOrCommodityProps.base.id;

            require(timedMarketAssets[assetId].base.isWhitelisted, "Base TimedMarketAsset does not exist");

            // Correctly referencing the base Asset struct
            AssetLib.AssetProps storage baseAsset = timedMarketAssets[assetId].base;

            timedMarketAssets[assetId] = forexOrCommodityProps;

        emit TimedMarketAssetAdded(
        assetId,
        forexOrCommodityProps.maxLeverageFactor,
        forexOrCommodityProps.positionSizeReserveFactor,
        forexOrCommodityProps.MAXIMUM_POSITION_SIZE_PER_MARKET,
        forexOrCommodityProps.MAX_POSITION_PNL_FACTOR,
        forexOrCommodityProps.MAX_GLOBAL_PNL_FACTOR
    );
    }

    function updateTimedMarketAssetReferenceAsset(
        uint256 _assetId,
        string memory _referenceAsset
    ) external onlyOwner {
        timedMarketAssets[_assetId].referenceAsset = _referenceAsset;

      emit TimedMarketAssetUpdated(_assetId, timedMarketAssets[_assetId].minLiquidityRequiredForExecution, _referenceAsset, timedMarketAssets[_assetId].marketOpenTimeStamp, timedMarketAssets[_assetId].marketOpenDurationsinSeconds);

    }

    function updateTimedMarketAssetMarketTimings(
        uint256 _assetId,
        uint256 _marketOpenTimestamp,
        uint256 _marketOpenDuration
    ) external onlyOwner {
        timedMarketAssets[_assetId].marketOpenTimeStamp = _marketOpenTimestamp;
        timedMarketAssets[_assetId].marketOpenDurationsinSeconds = _marketOpenDuration;

        emit TimedMarketAssetMarketTimingsUpdated(
        _assetId,
        _marketOpenTimestamp,
        _marketOpenDuration
    );

    }

    function batchUpdateAssets(
        AssetPropsUpdateOperation[] memory assetPropsUpdates,
        TimedMarketAssetPropsUpdateOperation[] memory timedMarketAssetPropsUpdates
    ) external  onlyOwner {
        for (uint i = 0; i < assetPropsUpdates.length; i++) {
            AssetPropsUpdateOperation memory op = assetPropsUpdates[i];
            require(cryptoAssets[op.assetId].isWhitelisted, "Asset does not exist");

            // Process each flag for AssetProps
            if (op.updateMinLiquidityRequiredForExecution) {
                cryptoAssets[op.assetId].minLiquidityRequiredForExecution = op.newValues.minLiquidityRequiredForExecution;
            }
            if (op.updateIsWhitelisted) {
                cryptoAssets[op.assetId].isWhitelisted = op.newValues.isWhitelisted;
            }
            if (op.updateChainIdAllowed) {
                cryptoAssets[op.assetId].chainIdAllowed = op.newValues.chainIdAllowed;
            }
            if (op.updateAssetAddressByChainId) {
                cryptoAssets[op.assetId].assetAddressByChainId = op.newValues.assetAddressByChainId;
            }
            if (op.updateTOKEN_DECIMALS_PRECISION) {
                cryptoAssets[op.assetId].TOKEN_DECIMALS_PRECISION = op.newValues.TOKEN_DECIMALS_PRECISION;
            }
            if (op.updateTOKEN_PRICE_PRECISION) {
                cryptoAssets[op.assetId].TOKEN_PRICE_PRECISION = op.newValues.TOKEN_PRICE_PRECISION;
            }
            if (op.updateIsIsolatedPoolStatus) {
                cryptoAssets[op.assetId].isIsolatedPoolAllowed = op.newValues.isIsolatedPoolAllowed;
            }
            if (op.updateIsSharedPoolStatus) {
                cryptoAssets[op.assetId].isSharedPoolAllowed = op.newValues.isSharedPoolAllowed;
            }
            if (op.updateIsDecentralisedSourceEnabled) {
                cryptoAssets[op.assetId].isDecentralisedSourceEnabled = op.newValues.isDecentralisedSourceEnabled;
            }
            if (op.updateIsCentralisedSourceEnabled) {
                cryptoAssets[op.assetId].isCentralisedSourceEnabled = op.newValues.isCentralisedSourceEnabled;
            }
            if (op.updateIsShortable) {
                cryptoAssets[op.assetId].tradeProps.isShortable = op.newValues.tradeProps.isShortable;
            }
            if (op.updateIsStable) {
                cryptoAssets[op.assetId].tradeProps.isStable = op.newValues.tradeProps.isStable;
            }
            if (op.updateIsLongable) {
                cryptoAssets[op.assetId].tradeProps.isLongable = op.newValues.tradeProps.isLongable;
            }
            if (op.updateIsCollateral) {
                cryptoAssets[op.assetId].tradeProps.isCollateral = op.newValues.tradeProps.isCollateral;
            }
            if (op.updateIsReference) {
                cryptoAssets[op.assetId].tradeProps.isReference = op.newValues.tradeProps.isReference;
            }
            if (op.updateIsSwapEnabled) {
                cryptoAssets[op.assetId].marketProps.isSwapEnabled = op.newValues.marketProps.isSwapEnabled;
            }
            if (op.updateIsMarginTradingEnabled) {
                cryptoAssets[op.assetId].marketProps.isMarginTradingEnabled = op.newValues.marketProps.isMarginTradingEnabled;
            }
            if (op.updateIsLimitOrderBookEnabled) {
                cryptoAssets[op.assetId].marketProps.isLimitOrderBookEnabled = op.newValues.marketProps.isLimitOrderBookEnabled;
            }
            if (op.updateIsExternalLiquidityEnabled) {
                cryptoAssets[op.assetId].marketProps.isExternalLiquidityEnabled = op.newValues.marketProps.isExternalLiquidityEnabled;
            }
            if (op.update_maxLeverageFactor) {
                cryptoAssets[op.assetId].riskProps.maxLeverageFactor = op.newValues.riskProps.maxLeverageFactor;
            }
            if (op.update_positionSizeReserveFactor) {
                cryptoAssets[op.assetId].riskProps.positionSizeReserveFactor = op.newValues.riskProps.positionSizeReserveFactor;
            }
            if (op.update_MAXIMUM_POSITION_SIZE_PER_MARKET) {
                cryptoAssets[op.assetId].riskProps.MAXIMUM_POSITION_SIZE_PER_MARKET = op.newValues.riskProps.MAXIMUM_POSITION_SIZE_PER_MARKET;
            }
            if (op.update_MAX_POSITION_PNL_FACTOR) {
                cryptoAssets[op.assetId].riskProps.MAX_POSITION_PNL_FACTOR = op.newValues.riskProps.MAX_POSITION_PNL_FACTOR;
            }
            if (op.update_MAX_GLOBAL_PNL_FACTOR) {
                cryptoAssets[op.assetId].riskProps.MAX_GLOBAL_PNL_FACTOR = op.newValues.riskProps.MAX_GLOBAL_PNL_FACTOR;
            }
            emit AssetUpdated(
              op.assetId,
              op.newValues.minLiquidityRequiredForExecution,
              op.newValues.isWhitelisted,
              op.newValues.chainIdAllowed,
              op.newValues.assetAddressByChainId,
              op.newValues.TOKEN_DECIMALS_PRECISION,
              op.newValues.TOKEN_PRICE_PRECISION,
              op.newValues.isIsolatedPoolAllowed,
              op.newValues.isSharedPoolAllowed,
              op.newValues.isDecentralisedSourceEnabled,
              op.newValues.isCentralisedSourceEnabled,
              op.newValues.tradeProps.isShortable,
              op.newValues.tradeProps.isStable,
              op.newValues.tradeProps.isLongable,
              op.newValues.tradeProps.isCollateral,
              op.newValues.tradeProps.isReference,
              op.newValues.marketProps.isSwapEnabled,
              op.newValues.marketProps.isMarginTradingEnabled,
              op.newValues.marketProps.isLimitOrderBookEnabled,
              op.newValues.marketProps.isExternalLiquidityEnabled,
              op.newValues.riskProps.maxLeverageFactor,
              op.newValues.riskProps.positionSizeReserveFactor,
              op.newValues.riskProps.MAXIMUM_POSITION_SIZE_PER_MARKET,
              op.newValues.riskProps.MAX_POSITION_PNL_FACTOR,
              op.newValues.riskProps.MAX_GLOBAL_PNL_FACTOR
            );
         }

        for (uint i = 0; i < timedMarketAssetPropsUpdates.length; i++) {
            TimedMarketAssetPropsUpdateOperation memory op = timedMarketAssetPropsUpdates[i];
            require(timedMarketAssets[op.assetId].base.isWhitelisted, "TimedMarketAsset does not exist");

            // Process each flag for TimedMarketAssetProps
            if (op.updateReferenceAsset) {
                timedMarketAssets[op.assetId].referenceAsset = op.newValues.referenceAsset;
                // emit TimedMarketAssetUpdated(op.assetId, timedMarketAssets[op.assetId].minLiquidityRequiredForExecution, op.newValues.referenceAsset, timedMarketAssets[op.assetId].marketOpenTimeStamp, timedMarketAssets[op.assetId].marketOpenDurationsinSeconds);

            }
            if (op.updateMarketOpenTimeStamp) {
                timedMarketAssets[op.assetId].marketOpenTimeStamp = op.newValues.marketOpenTimeStamp;
            }
            if (op.updateMarketOpenDurationsinSeconds) {
                timedMarketAssets[op.assetId].marketOpenDurationsinSeconds = op.newValues.marketOpenDurationsinSeconds;
            }
            emit TimedMarketAssetUpdated(
              op.assetId,
              op.newValues.minLiquidityRequiredForExecution,
              op.newValues.referenceAsset,
              op.newValues.marketOpenTimeStamp,
              op.newValues.marketOpenDurationsinSeconds
            );
        }
    }

    

    function getAssetReferencePrice(uint256 assetId) public view returns (uint256[] memory) {
        uint256[] memory price = new uint256[](1); // Assuming 1 liquidity source: market
        
        AssetLib.SpreadData memory spread = spreadData[assetId];
        AssetLib.DeviationData memory deviation = deviationData[assetId];

        for (uint256 i = 0; i < price.length; i++) {
            if (spread.spreadEnabled) {
                price[i] = applySpread(price[i], spread.longSpreadPercentage, true); // True for long position
                price[i] = applySpread(price[i], spread.shortSpreadPercentage, false); // False for short position
            }
            if (!isPriceWithinDeviation(price[i], deviation.referencePrice, deviation.maxDeviationPercentage)) {
                price[i] = handleDeviation(price[i], deviation.referencePrice, deviation.maxDeviationPercentage);
            }
        }

      return price;
    }

   function applySpread(uint256 price, uint256 spreadPercentage, bool isLong) private pure returns (uint256) {
      if (isLong) {
          return price + (price * spreadPercentage / 10000);
      } else {
          return price - (price * spreadPercentage / 10000);
      }
   }

    function isPriceWithinDeviation(
        uint256 price, 
        uint256 referencePrice, 
        uint256 maxDeviationPercentage
    ) private pure returns (bool) {
        uint256 deviationAmount = referencePrice * maxDeviationPercentage / 10000; // Assuming maxDeviationPercentage is in basis points
        uint256 minAcceptablePrice = referencePrice - deviationAmount;
        uint256 maxAcceptablePrice = referencePrice + deviationAmount;

        return price >= minAcceptablePrice && price <= maxAcceptablePrice;
    }

    function handleDeviation(
      uint256 price, 
      uint256 referencePrice, 
      uint256 maxDeviationPercentage
   ) private pure returns (uint256) {
      // Deviation is calculated as a percentage of the reference price
      // where 1% = 100 basis points
      uint256 deviationAmount = referencePrice * maxDeviationPercentage / 10000; // Assuming maxDeviationPercentage is in basis points
      uint256 minAcceptablePrice = referencePrice - deviationAmount;
      uint256 maxAcceptablePrice = referencePrice + deviationAmount;

      if (price < minAcceptablePrice) {
         return minAcceptablePrice;
      } else if (price > maxAcceptablePrice) {
         return maxAcceptablePrice;
      } else {
         return price;
      }
   }
   

    function isMarketOpen(uint256 assetId) public view returns (bool) {
        AssetLib.TimedMarketAssetProps memory asset = timedMarketAssets[assetId];
        uint256 currentTime = block.timestamp;
        return currentTime >= asset.marketOpenTimeStamp && currentTime <= asset.marketOpenTimeStamp + asset.marketOpenDurationsinSeconds;
    }

   /// @notice Aggregates liquidity from different sources for an asset.
//    function getAggregateLiquidity(uint256 assetId) external view returns (uint256) {
//         uint256 marketLiquidity = getMarketLiquidity(assetId); // needs to be implemented
//         // uint256 limitOrderBookLiquidity = getLimitOrderBookLiquidity(assetId);
//       //   uint256 elpLiquidity = getElpLiquidity(assetId);
//       //   uint256 p2pLiquidity = getP2PLiquidity(assetId);

//         return marketLiquidity /*+ limitOrderBookLiquidity + elpLiquidity + p2pLiquidity*/;
//     }

//     function getRequiredLiquidity(uint256 assetId) external view returns (uint256) {
//     AssetLib.AssetRequirements memory requirements = assetRequirements[assetId];
//     if (requirements.assetType == AssetLib.AssetTypeEnum.TimedMarketAsset) {
//         return requirements.minLiquidityRequiredForExecution * 2; // Increased liquidity for volatile markets
//     }
//     return requirements.minLiquidityRequiredForExecution;
// }


//     function setAssetRequirements(uint256 assetId, AssetLib.AssetTypeEnum assetType, uint256 minLiquidity) external onlyOwner {
//     assetRequirements[assetId] = AssetLib.AssetRequirements({
//         assetType: assetType,
//         minLiquidityRequiredForExecution: minLiquidity
//     });
// }


    
    function getAssetPriceFromMarket(uint256 assetId) external view returns (uint256) {
        AssetLib.PoolMarketData memory marketData = queryMarketContract(assetId);
        require(marketData.isValid, "Market data not valid");
        return marketData.price;
    }

    // These would be replaced with actual queries to smart contracts or off-chain APIs
    function queryMarketContract(uint256 assetId) private view returns (AssetLib.PoolMarketData memory) {
        // Fetch market data
        return AssetLib.PoolMarketData({price: 0, isValid: true}); // Placeholder
    }

    // // Function to get the total liquidity of a specific market
     function getMarketLiquidity(uint256 marketId) public view returns (uint256) {
        require(marketId != 0, "Invalid market ID");

        // Use the interface instance to get the pool value
        uint256 poolValueUsd = marketStorageModuleInstance.getPoolValueByMarketId(marketId);

        return poolValueUsd;
    }

   function setSpreadData(uint256 assetId, uint256 longSpreadPercentage, uint256 shortSpreadPercentage, bool spreadEnabled) external onlyOwner {
      spreadData[assetId] = AssetLib.SpreadData(longSpreadPercentage, shortSpreadPercentage, spreadEnabled);
   }

   function setDeviationData(uint256 assetId, uint256 referencePrice, uint256 maxDeviationPercentage) external  onlyOwner {
      deviationData[assetId] = AssetLib.DeviationData(referencePrice, maxDeviationPercentage);
   }

   function getMinLiquidityRequiredForExecution(uint256 assetId) external view  returns (uint256[] memory) {
        return cryptoAssets[assetId].minLiquidityRequiredForExecution;
    }

    function getIsWhitelisted(uint256 assetId) external view  returns (bool) {
        return cryptoAssets[assetId].isWhitelisted;
    }

    function getChainIdAllowed(uint256 assetId) external view  returns (uint256[] memory) {
        return cryptoAssets[assetId].chainIdAllowed;
    }

    function getAssetAddressByChainId(uint256 assetId, uint256 chainIdIndex) external view  returns (address) {
        return cryptoAssets[assetId].assetAddressByChainId[chainIdIndex];
    }

    function getTokenDecimalsPrecision(uint256 assetId) external view  returns (uint256) {
        return cryptoAssets[assetId].TOKEN_DECIMALS_PRECISION;
    }

    function getTokenPricePrecision(uint256 assetId) external view  returns (uint256) {
        return cryptoAssets[assetId].TOKEN_PRICE_PRECISION;
    }

    function getAssetDecentralisedSourceStatus(uint256 _assetId) external view returns(bool) {
        return cryptoAssets[_assetId].isDecentralisedSourceEnabled;
    }

    function getAssetCentralisedSourceStatus(uint256 _assetId) external view returns(bool) {
        return cryptoAssets[_assetId].isCentralisedSourceEnabled;
    }

    function getAssetTradeProps(uint256 _assetId) external view returns(bool, bool, bool, bool, bool) { 
        AssetLib.AssetProps memory asset = cryptoAssets[_assetId];
        return (asset.tradeProps.isReference, asset.tradeProps.isLongable, asset.tradeProps.isShortable, asset.tradeProps.isStable, asset.tradeProps.isCollateral);
    }

    function getAssetTickByAssetId(uint256 _assetId) external view returns(bytes32) {
        return cryptoAssets[_assetId].assetTickName;
    }


    // Batch execution function
    // function getMultipleAssetProperties(uint256 assetId, uint8[] calldata properties) external view  returns (bytes[] memory) {
    //     bytes[] memory results = new bytes[](properties.length);
    //     for (uint256 i = 0; i < properties.length; i++) {
    //         if (properties[i] == 1) {
    //             results[i] = abi.encode(getMinLiquidityRequiredForExecution(assetId));
    //         } else if (properties[i] == 2) {
    //             results[i] = abi.encode(getIsWhitelisted(assetId));
    //         } else if (properties[i] == 3) {
    //             results[i] = abi.encode(getChainIdAllowed(assetId));
    //         } else if (properties[i] == 4) {
    //             results[i] = abi.encode(getAssetAddressByChainId(assetId));
    //         } else if (properties[i] == 5) {
    //             results[i] = abi.encode(getTokenDecimalsPrecision(assetId));
    //         } else if (properties[i] == 6) {
    //             results[i] = abi.encode(getTokenPricePrecision(assetId));
    //         }
    //         // ... [additional conditions for other properties] ...
    //     }
    //     return results;
    // }


    // function getPricesByAssetIdFromOracle(
    //         uint256 _assetId
    //     ) external  returns(uint256 priceFromDecentralisedSource, uint256 priceFromCentralisedSource) {
    //         // interact with oracle to get prices
    //     }
}

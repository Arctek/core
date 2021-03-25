// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov (az@unit.xyz).
*/
pragma solidity ^0.7.1;


interface IVaultManagerParameters {
    function setInitialCollateralRatio(address, uint) external;
    function setLiquidationRatio(address, uint) external;
    function setLiquidationDiscount(address, uint) external;
    function setDevaluationPeriod(address, uint) external;
    function setCollateral(
        address,
        uint,
        uint,
        uint,
        uint,
        uint,
        uint,
        uint,
        uint[] calldata,
        uint,
        uint
    ) external;

    function vaultParameters() external view returns (address);
}


interface IBearingAssetOracleSimple {
    function setUnderlying(address, address) external;
    function oracleRegistry() external view returns (address);
}


interface IOracleRegistry {
    function setOracle(address, address, uint) external;
    function oracleByType(uint) external view returns (address);
}


interface ICollateralRegistry {
    function addCollateral(address) external;
    function removeCollateral(address) external;
}


interface IVault {
    function changeOracleType(address, address, uint) external;
}


interface IVaultParameters {
    function setManager(address, bool) external;
    function setVaultAccess(address, bool) external;
    function setStabilityFee(address, uint) external;
    function setLiquidationFee(address, uint) external;
    function setOracleType(uint, address, bool) external;
    function setTokenDebtLimit(address, uint) external;

    function isManager(address) external view returns (bool);
    function canModifyVault(address) external view returns (bool);
    function vault() external view returns (address);
}


/**
 * @title Auth
 * @author Unit Protocol: Artem Zakharov (az@unit.xyz), Alexander Ponomorev (@bcngod)
 * @dev Manages USDP's system access
 **/
contract Auth {

    // address of the the contract with vault parameters
    IVaultParameters public vaultParameters;

    constructor(address _parameters) {
        vaultParameters = IVaultParameters(_parameters);
    }

    // ensures tx's sender is a manager
    modifier onlyManager() {
        require(vaultParameters.isManager(msg.sender), "Unit Protocol: AUTH_FAILED");
        _;
    }

    // ensures tx's sender is able to modify the Vault
    modifier hasVaultAccess() {
        require(vaultParameters.canModifyVault(msg.sender), "Unit Protocol: AUTH_FAILED");
        _;
    }

    // ensures tx's sender is the Vault
    modifier onlyVault() {
        require(msg.sender == vaultParameters.vault(), "Unit Protocol: AUTH_FAILED");
        _;
    }
}


/**
 * @title ParametersBatchUpdater
 **/
contract ParametersBatchUpdater is Auth {

    IVaultManagerParameters public immutable vaultManagerParameters;
    IOracleRegistry public immutable oracleRegistry;
    ICollateralRegistry public immutable collateralRegistry;

    uint public constant BEARING_ASSET_ORACLE_TYPE = 9;

    constructor(
        address _vaultManagerParameters,
        address _oracleRegistry,
        address _collateralRegistry
    ) Auth(IVaultManagerParameters(_vaultManagerParameters).vaultParameters()) {
        require(
            _vaultManagerParameters != address(0) &&
            _oracleRegistry != address(0) &&
            _collateralRegistry != address(0), "Unit Protocol: ZERO_ADDRESS");
        vaultManagerParameters = IVaultManagerParameters(_vaultManagerParameters);
        oracleRegistry = IOracleRegistry(_oracleRegistry);
        collateralRegistry = ICollateralRegistry(_collateralRegistry);
    }

    /**
     * @notice Only manager is able to call this function
     * @dev Grants and revokes manager's status
     * @param who The array of target addresses
     * @param permit The array of permission flags
     **/
    function setManagers(address[] calldata who, bool[] calldata permit) external onlyManager {
        require(who.length == permit.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < who.length; i++) {
            vaultParameters.setManager(who[i], permit[i]);
        }
    }

    /**
     * @notice Only manager is able to call this function
     * @dev Sets a permission for provided addresses to modify the Vault
     * @param who The array of target addresses
     * @param permit The array of permission flags
     **/
    function setVaultAccesses(address[] calldata who, bool[] calldata permit) external onlyManager {
        require(who.length == permit.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < who.length; i++) {
            vaultParameters.setVaultAccess(who[i], permit[i]);
        }
    }

    /**
     * @notice Only manager is able to call this function
     * @dev Sets the percentage of the year stability fee for a particular collateral
     * @param assets The array of addresses of the main collateral tokens
     * @param newValues The array of stability fee percentages (3 decimals)
     **/
    function setStabilityFees(address[] calldata assets, uint[] calldata newValues) public onlyManager {
        require(assets.length == newValues.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < assets.length; i++) {
            vaultParameters.setStabilityFee(assets[i], newValues[i]);
        }
    }

    /**
     * @notice Only manager is able to call this function
     * @dev Sets the percentages of the liquidation fee for provided collaterals
     * @param assets The array of addresses of the main collateral tokens
     * @param newValues The array of liquidation fee percentages (0 decimals)
     **/
    function setLiquidationFees(address[] calldata assets, uint[] calldata newValues) public onlyManager {
        require(assets.length == newValues.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < assets.length; i++) {
            vaultParameters.setLiquidationFee(assets[i], newValues[i]);
        }
    }

    /**
     * @notice Only manager is able to call this function
     * @dev Enables/disables oracle types
     * @param _types The array of types of the oracles
     * @param assets The array of addresses of the main collateral tokens
     * @param flags The array of control flags
     **/
    function setOracleTypes(uint[] calldata _types, address[] calldata assets, bool[] calldata flags) public onlyManager {
        require(_types.length == assets.length && _types.length == flags.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < _types.length; i++) {
            vaultParameters.setOracleType(_types[i], assets[i], flags[i]);
        }
    }

    /**
     * @notice Only manager is able to call this function
     * @dev Sets USDP limits for a provided collaterals
     * @param assets The addresses of the main collateral tokens
     * @param limits The borrow USDP limits
     **/
    function setTokenDebtLimits(address[] calldata assets, uint[] calldata limits) public onlyManager {
        require(assets.length == limits.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < assets.length; i++) {
            vaultParameters.setTokenDebtLimit(assets[i], limits[i]);
        }
    }

    function changeOracleTypes(address[] calldata assets, address[] calldata users, uint[] calldata oracleTypes) public onlyManager {
        require(assets.length == users.length && assets.length == oracleTypes.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < assets.length; i++) {
            IVault(vaultParameters.vault()).changeOracleType(assets[i], users[i], oracleTypes[i]);
        }
    }

    function setInitialCollateralRatios(address[] calldata assets, uint[] calldata values) public onlyManager {
        require(assets.length == values.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < assets.length; i++) {
            vaultManagerParameters.setInitialCollateralRatio(assets[i], values[i]);
        }
    }

    function setLiquidationRatios(address[] calldata assets, uint[] calldata values) public onlyManager {
        require(assets.length == values.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < assets.length; i++) {
            vaultManagerParameters.setLiquidationRatio(assets[i], values[i]);
        }
    }

    function setLiquidationDiscounts(address[] calldata assets, uint[] calldata values) public onlyManager {
        require(assets.length == values.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < assets.length; i++) {
            vaultManagerParameters.setLiquidationDiscount(assets[i], values[i]);
        }
    }

    function setDevaluationPeriods(address[] calldata assets, uint[] calldata values) public onlyManager {
        require(assets.length == values.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < assets.length; i++) {
            vaultManagerParameters.setDevaluationPeriod(assets[i], values[i]);
        }
    }

    function setOraclesInRegistry(address[] calldata assets, address[] calldata oracles, uint[] calldata oracleTypes) public onlyManager {
        require(assets.length == oracles.length && assets.length == oracleTypes.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < assets.length; i++) {
            oracleRegistry.setOracle(assets[i], oracles[i], oracleTypes[i]);
        }
    }

    function setUnderlyings(address[] calldata bearings, address[] calldata underlyings) public onlyManager {
        require(bearings.length == underlyings.length, "Unit Protocol: ARGUMENTS_LENGTH_MISMATCH");
        for (uint i = 0; i < bearings.length; i++) {
            IBearingAssetOracleSimple(oracleRegistry.oracleByType(BEARING_ASSET_ORACLE_TYPE)).setUnderlying(bearings[i], underlyings[i]);
        }
    }

    function setCollaterals(
        address[] calldata assets,
        uint stabilityFeeValue,
        uint liquidationFeeValue,
        uint initialCollateralRatioValue,
        uint liquidationRatioValue,
        uint liquidationDiscountValue,
        uint devaluationPeriodValue,
        uint usdpLimit,
        uint[] calldata oracles
    ) external onlyManager {
        for (uint i = 0; i < assets.length; i++) {
            vaultManagerParameters.setCollateral(
                assets[i],
                stabilityFeeValue,
                liquidationFeeValue,
                initialCollateralRatioValue,
                liquidationRatioValue,
                liquidationDiscountValue,
                devaluationPeriodValue,
                usdpLimit,
                oracles,
                0,
                0
            );

            collateralRegistry.addCollateral(assets[i]);
        }
    }

    function setCollateralAddresses(address[] calldata assets, bool add) external onlyManager {
        for (uint i = 0; i < assets.length; i++) {
            add ? collateralRegistry.addCollateral(assets[i]) : collateralRegistry.removeCollateral(assets[i]);
        }
    }
}

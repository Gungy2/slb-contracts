// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./device.sol";

contract SLB_Bond is Ownable, Pausable, IoT_Device, IERC20 {
    address public verifier;
    address public issuer;

    uint256 public bondPrice; //price of each bond unit
    uint256 public periods;

    // interest rates - base/penalty
    uint256 public coupon;
    uint256 public interestPenalty;

    string public description;
    uint256 public activeDate;
    uint256 public maturityDate;
    uint256 public finalRedemptionDate;
    uint256 public currentPeriod = 0; //counter

    uint256 public bondsForSale;
    uint256 public totalBondsIssued;
    uint256 public totalDebt; //total unpaid debt

    enum BondState {
        PREISSUE,
        ISSUED,
        ACTIVE,
        BANKRUPT,
        REDEEMED
    }

    enum KPI {
        NONE,
        GHG,
        RECYCLED,
        SOCIAL
    } //customisable

    uint256 public impactData_1;
    uint256 public impactData_2;
    uint256 public impactData_3;

    mapping(address => uint256) bondsCount;
    mapping(address => uint256[]) fundsToClaim;
    mapping(address => mapping(address => uint256)) private allowances;

    BondState public status;
    bool public isReported = false;
    bool public isVerified = false;

    KPI[] public kpis;
    bool[] public metKPIs;

    // EVENTS
    event SetRoles(address issuer, address verifier);

    event SetUpBond(address issuer, uint256 totalBondsIssued);

    event DepositedFunds(address issuer, uint256 funds);

    event ContractFunded(uint256 amount, uint256 gas);

    event MintedBond(address buyer, uint256 bondsPurchased);

    event ReportedImpact(bytes32 _signature);

    event VerifiedImpact(bool metKPIs);

    event ClaimedCoupons(address buyer, uint256 currentPeriod);

    event ClaimedPrincipal(address buyer, uint256 currentPeriod);

    event ClaimedDefault(address buyer, uint256 bondsPurchased);

    event Freeze();

    event Unfreeze();

    constructor() payable {}

    // MODIFIERS
    modifier onlyVerifier() {
        require(msg.sender == verifier, "Not verifier");
        _;
    }

    modifier onlyIssuer() {
        require(msg.sender == issuer, "Not issuer");
        _;
    }

    /**
     * @dev Role: MASTER, Bond state: Pre-issue
     * @notice Sets the issuer and verifier addresses
     */
    function setRoles(address _issuer, address _verifier) external onlyOwner {
        issuer = _issuer;
        verifier = _verifier;

        emit SetRoles(issuer, verifier);
    }

    /**
     * @dev Role: ISSUER, Bond state: Pre-issue
     * @notice Sets the bond details and issues bond
     */
    function setBond(
        string memory _description,
        KPI[] memory _KPIs,
        uint256 _bondPrice,
        uint256 _periods,
        uint256 _baseCouponRate,
        uint256 _interestPenalty,
        uint256 _totalBonds,
        uint256 _activeDate,
        uint256 _maturityDate,
        uint256 _finalRedemptionDate
    ) external onlyIssuer {
        require(status == BondState.PREISSUE, "Bond status is not Pre-Issue.");
        require(_bondPrice > 0, "Bond price should be positive");
        require(_baseCouponRate > 0, "Base coupon rate should be positive");
        require(_periods > 0, "Number of periods should be at least 1");
        require(
            _activeDate > block.timestamp,
            "Active date should be after current date"
        );
        require(
            _maturityDate > _activeDate,
            "Maturity date should be after active date"
        );
        require(
            _finalRedemptionDate > _maturityDate,
            "Redemption date should be after maturity date"
        );
        require(_totalBonds > 0, "Number of bonds should be at least 1");

        description = _description;
        bondPrice = _bondPrice;
        periods = _periods;
        coupon = _baseCouponRate;
        interestPenalty = _interestPenalty;
        activeDate = _activeDate;
        maturityDate = _maturityDate;
        finalRedemptionDate = _finalRedemptionDate;
        totalBondsIssued = _totalBonds;

        for (uint32 i = 0; i < _KPIs.length; i++) {
            if (_KPIs[i] != KPI.NONE) {
                kpis.push(_KPIs[i]);
            }
        }

        bondsForSale = totalBondsIssued;

        status = BondState.ISSUED;

        emit SetUpBond(payable(msg.sender), totalBondsIssued);
    }

    /**
     * @dev Role: ISSUER, Bond state: Any state other than Bankrupt or Redeemed
     * @notice Tops up funds to bond balance
     */
    function fundBond() external payable onlyIssuer whenNotPaused {
        require(status != BondState.REDEEMED, "Bond status is Redeemed.");
        require(status != BondState.BANKRUPT, "Bond status is Bankrupt.");
        emit DepositedFunds(payable(msg.sender), msg.value);
    }

    /**
     * @dev Role: ISSUER, Bond state: Any state other than Bankrupt or Redeemed
     * @notice Withdraws funds from bond balance
     */
    function withdrawMoney(uint256 _value) external onlyIssuer whenNotPaused {
        require(_value <= address(this).balance, "Insufficient balance.");
        require(status != BondState.BANKRUPT, "Bond status is Bankrupt.");
        payable(msg.sender).transfer(_value);
    }

    /**
     * @dev Role: INVESTOR, Bond state: Issued
     * @notice Purchase bonds
     */
    function mintBond(uint _bondsPurchased) external payable whenNotPaused {
        require(msg.sender != issuer);
        require(bondsForSale >= 1, "No bonds issued");
        require(status == BondState.ISSUED, "Bond status is not Issued.");
        require(block.timestamp < activeDate, "Bond buying window has closed.");

        if (bondsCount[msg.sender] > 0) {
            for (uint32 i = 0; i <= periods; i++) {
                fundsToClaim[msg.sender][i] += _bondsPurchased;
            }
        } else {
            // First time purchase
            for (uint32 i = 0; i <= periods; i++) {
                fundsToClaim[msg.sender].push(_bondsPurchased);
            }
        }

        bondsCount[msg.sender] = bondsCount[msg.sender] + _bondsPurchased;

        totalDebt = totalDebt + bondPrice * _bondsPurchased;

        bondsForSale = bondsForSale - _bondsPurchased;

        emit MintedBond(msg.sender, _bondsPurchased);
    }

    /**
     * @dev Role: ISSUER, Bond state: Issued
     * @notice Sets bond status to Active at end of buying period
     */
    function setBondActive() external onlyIssuer whenNotPaused {
        require(status == BondState.ISSUED, "Bond status is not Issued.");
        require(block.timestamp >= activeDate, "Active date is not reached.");

        status = BondState.ACTIVE;
    }

    /**
     * @dev Role: Any, Bond state: Any
     * @notice Calculates coupon date for each period
     */
    function couponDateCalculator(
        uint256 _activeDate,
        uint256 _maturityDate,
        uint256 _periods,
        uint256 _currentPeriod
    ) public pure returns (uint256) {
        uint256 _couponDate;
        uint256 _term = (_maturityDate - _activeDate) / _periods;
        _couponDate = _activeDate + _term * _currentPeriod;
        return _couponDate;
    }

    /**
     * @dev Role: ISSUER, Bond state: Active
     * @notice Reports impact data for the period
     */
    function reportImpact(
        uint256 _impactData_1,
        uint256 _impactData_2,
        uint256 _impactData_3,
        string memory _id,
        bytes32 _signature
    ) external onlyIssuer whenNotPaused {
        require(status == BondState.ACTIVE, "Bond status is not Active.");
        // couponDate calculations
        currentPeriod++;
        require(
            block.timestamp >=
                couponDateCalculator(
                    activeDate,
                    maturityDate,
                    periods,
                    currentPeriod
                ),
            "Current date is not past coupon date"
        );
        require(
            checkDevice(
                _id,
                _signature,
                _impactData_1,
                _impactData_2,
                _impactData_3
            ) == true,
            "invalid signature"
        );

        if (_impactData_1 > 0) {
            if (impactData_1 == 0) {
                impactData_1 = _impactData_1;
            } else {
                impactData_1 = (impactData_1 + _impactData_1) / currentPeriod;
            }
        }
        if (_impactData_2 > 0) {
            if (impactData_2 == 0) {
                impactData_2 = _impactData_2;
            } else {
                impactData_2 = (impactData_2 + _impactData_2) / currentPeriod;
            }
        }
        if (_impactData_3 > 0) {
            if (impactData_3 == 0) {
                impactData_3 = _impactData_3;
            } else {
                impactData_3 = (impactData_3 + _impactData_3) / currentPeriod;
            }
        }
        isReported = true;
        isVerified = false;

        emit ReportedImpact(_signature);
    }

    /**
     * @dev Role: VERIFIER, Bond state: Active
     * @notice Verify impact data by setting KPI status
     */
    function verifyImpact(bool _metKPIs) external onlyVerifier whenNotPaused {
        require(status == BondState.ACTIVE, "Bond status is not Active.");
        require(isReported == true, "Impact data has not been reported.");

        metKPIs.push(_metKPIs);
        // isReported = false; //NOTE: NO RESETTING - REPORTING PERIOD CHANGES AT EACH REPORT
        isVerified = true;

        emit VerifiedImpact(_metKPIs);
    }

    /**
     * @dev Role: Any, Bond state: Any
     * @notice Checks if bond balance is sufficient
     */
    function checkBalance(uint256 _value) public view returns (bool) {
        bool _balanceSufficient;
        if (address(this).balance < _value) {
            _balanceSufficient = false;
            return _balanceSufficient;
        }
        _balanceSufficient = true;
        return _balanceSufficient;
    }

    /**
     * @dev Role: Any, Bond state: Any
     * @notice Calculates coupon amount for period based on KPI status
     */
    function couponCalculator(
        uint256 _bondsPurchased,
        uint256 _claimPeriod
    ) public view returns (uint256) {
        uint256 _coupon = 0;
        if (metKPIs[_claimPeriod - 1] == true) {
            _coupon = coupon * _bondsPurchased;
            return _coupon;
        } else {
            _coupon = (coupon + interestPenalty) * _bondsPurchased;
            return _coupon;
        }
    }

    /**
     * @dev Role: INVESTOR, Bond state: Active
     * @notice Claim coupon amount from bond balance for the period.
     * If bond balance has insufficient funds, set bond status to Bankrupt.
     */
    function claimCoupon(uint256 _claimPeriod) public whenNotPaused {
        require(status == BondState.ACTIVE, "Bond status is not Active.");
        require(isVerified, "Impact data has not been verified.");
        require(bondsCount[msg.sender] > 0, "No bonds purchased");
        require(
            _claimPeriod <= currentPeriod,
            "This period's coupon is not yet available."
        );

        // call internal calculation function for value
        uint256 unclaimedBonds = fundsToClaim[msg.sender][_claimPeriod - 1];
        require(unclaimedBonds > 0, "No coupons to claim");
        uint256 _value = couponCalculator(bondsCount[msg.sender], _claimPeriod);

        //check balance for value at each
        if (checkBalance(_value)) {
            payable(msg.sender).transfer(_value);
            fundsToClaim[msg.sender][_claimPeriod - 1] = 0;
            emit ClaimedCoupons(msg.sender, _claimPeriod);
        } else {
            status = BondState.BANKRUPT;
        }
    }

    /**
     * @dev Role: INVESTOR, Bond state: Active
     * @notice Claim principal amount from bond balance at maturity.
     * If bond balance has insufficient funds, set bond status to Bankrupt.
     */
    function claimPrincipal() public whenNotPaused {
        require(status == BondState.ACTIVE, "Bond status is not Active.");
        require(isVerified == true, "Impact data has not been verified.");
        require(currentPeriod == periods, "Bond has not reached maturity.");
        require(bondsCount[msg.sender] > 0, "No bonds purchased");
        require(totalDebt > 0, "Investor has claimed principal.");

        uint256 totalBondsToClaim = fundsToClaim[msg.sender][currentPeriod];
        require(totalBondsToClaim > 0, "No principal to claim.");
        uint256 _value = bondPrice * totalBondsToClaim;

        //check balance for value at each
        if (checkBalance(_value)) {
            payable(msg.sender).transfer(_value);
            fundsToClaim[msg.sender][currentPeriod] = 0;
            totalDebt = totalDebt - _value;
            emit ClaimedPrincipal(msg.sender, currentPeriod);
        } else {
            status = BondState.BANKRUPT;
        }
    }

    /**
     * @dev Role: INVESTOR, Bond state: Bankrupt
     * Solidity does not support floating point calculations so proportion is already calculated from frontend
     * @notice Claim amount from bond balance by percentage of holdings
     */
    function defaultClaim(uint256 _value) public whenNotPaused {
        require(status == BondState.BANKRUPT, "Bond status is not Bankrupt.");
        require(bondsCount[msg.sender] > 0, "No bonds purchased");
        payable(msg.sender).transfer(_value);

        emit ClaimedDefault(msg.sender, bondsCount[msg.sender]);

        bondsCount[msg.sender] = 0;
    }

    /**
     * @dev Role: REGULATOR, Bond state: Any
     * @notice Freeze bond to halt all transactions
     */
    function freezeBond() public onlyOwner {
        _pause();
        emit Freeze();
    }

    /**
     * @dev Role: REGULATOR, Bond state: Any
     * @notice Unfreeze bond to revert to original state
     */
    function unfreezeBond() public onlyOwner {
        _unpause();
        emit Unfreeze();
    }

    /**
     * @dev Role: ISSUER, Bond state: Issued
     * @notice Sets bond status to Redeemed when no further bond activity is required
     */
    function setBondRedeemed() external onlyIssuer whenNotPaused {
        require(status == BondState.ACTIVE, "Bond status is not Active.");
        require(
            block.timestamp >= finalRedemptionDate,
            "Bond has not reached final redemption date."
        );

        status = BondState.REDEEMED;
    }

    //GETTER FUNCTIONS

    function getTotalPurchasedBonds() public view returns (uint256) {
        return totalBondsIssued - bondsForSale;
    }

    function getUsersPurchasedBonds(
        address _address
    ) public view returns (uint256) {
        return bondsCount[_address];
    }

    function getBalance() external view returns (uint) {
        return address(this).balance;
    }

    function getKPIs() external view returns (KPI[] memory) {
        return kpis;
    }

    // ERC20 IMPLEMENTATION

    function totalSupply() external view override returns (uint256) {
        return totalBondsIssued;
    }

    function balanceOf(
        address account
    ) external view override returns (uint256) {
        return bondsCount[account];
    }

    function transfer(
        address to,
        uint256 amount
    ) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view override returns (uint256) {
        return allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        require(
            msg.sender != address(0),
            "ERC20: approve from the zero address"
        );
        require(spender != address(0), "ERC20: approve to the zero address");

        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external override returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) private {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(
                currentAllowance >= amount,
                "ERC20: insufficient allowance"
            );
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (amount == 0) {
            emit Transfer(from, to, 0);
            return;
        }

        uint256 fromBalance = bondsCount[from];
        require(
            fromBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );
        require(
            status == BondState.ISSUED || status == BondState.ACTIVE,
            "Bonds cannot be transfered during the current state"
        );
        require(
            !_hasUnclaimedFunds(from),
            "Cannot transfer bonds from an account with unclaimed funds."
        );

        unchecked {
            bondsCount[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            bondsCount[to] += amount;
        }

        if (fundsToClaim[to].length == 0) {
            for (uint32 i = 0; i <= periods; i++) {
                fundsToClaim[to].push(0);
            }
        }

        for (uint256 i = currentPeriod; i <= periods; i++) {
            fundsToClaim[from][i] -= amount;
            fundsToClaim[to][i] += amount;
        }

        if (fromBalance == amount) {
            delete fundsToClaim[from];
        }

        emit Transfer(from, to, amount);
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _hasUnclaimedFunds(address account) internal view returns (bool) {
        if (status == BondState.ISSUED) {
            return false;
        }
        require(
            fundsToClaim[account].length > 0,
            "Account has not purchased any bonds"
        );

        for (uint256 i = 0; i < currentPeriod; i++) {
            if (fundsToClaim[account][i] > 0) {
                return true;
            }
        }
        return false;
    }
}

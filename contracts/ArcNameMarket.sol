// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ─────────────────────────────────────────────
//  Interfaces
// ─────────────────────────────────────────────
interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IRegistry {
    function getRecord(string memory name) external view returns (
        address nameOwner,
        uint256 expiry,
        uint256 registeredAt,
        bool    available
    );
    function transfer(string memory name, address to) external;
}

/**
 * @title  ArcNameMarket
 * @notice Peer-to-peer marketplace for .arc names.
 *         Sellers list names at a fixed USDC price.
 *         Buyers pay USDC → name transfers atomically → protocol takes 2.5% fee.
 *
 * Flow:
 *   1. Seller calls registry.transfer(name, MARKET_ADDRESS) to escrow the name.
 *   2. Seller calls market.list(name, price) to create a listing.
 *   3. Buyer calls market.buy(name) after approving USDC.
 *      → USDC split: seller gets 97.5%, protocol gets 2.5%.
 *      → Registry transfers name to buyer.
 *   4. Seller can cancel(name) at any time to reclaim their name.
 */
contract ArcNameMarket {

    // ── Constants ─────────────────────────────
    IERC20    public immutable usdc;
    IRegistry public immutable registry;
    address   public owner;

    uint256 public constant FEE_BPS = 250;        // 2.5% in basis points
    uint256 public constant BPS     = 10_000;

    // ── Storage ───────────────────────────────
    struct Listing {
        address seller;
        uint256 price;      // USDC, 6 decimals
        uint256 listedAt;   // unix timestamp
        bool    active;
    }

    mapping(string => Listing) private _listings;
    string[] private _listedNames;    // for enumeration

    // ── Events ────────────────────────────────
    event Listed(address indexed seller, string name, uint256 price);
    event Cancelled(address indexed seller, string name);
    event Sold(address indexed seller, address indexed buyer, string name, uint256 price, uint256 fee);

    // ── Constructor ───────────────────────────
    constructor(address _usdc, address _registry) {
        usdc     = IERC20(_usdc);
        registry = IRegistry(_registry);
        owner    = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // ── Seller actions ────────────────────────

    /**
     * @notice List a name for sale.
     *         IMPORTANT: Before calling this, transfer the name to this contract address
     *         via registry.transfer(name, address(this)).
     * @param  name   The .arc name to list (without extension)
     * @param  price  Sale price in USDC (6 decimals). e.g. 100 USDC = 100_000_000
     */
    function list(string memory name, uint256 price) external {
        require(price > 0, "Price must be > 0");

        // Verify this contract owns the name in the registry
        (address nameOwner,,,) = registry.getRecord(name);
        require(nameOwner == address(this), "Name not escrowed — transfer to market first");

        // Allow re-listing (update price)
        if (!_listings[name].active) {
            _listedNames.push(name);
        }

        _listings[name] = Listing({
            seller:   msg.sender,
            price:    price,
            listedAt: block.timestamp,
            active:   true
        });

        emit Listed(msg.sender, name, price);
    }

    /**
     * @notice Cancel a listing and reclaim the name.
     */
    function cancel(string memory name) external {
        Listing storage l = _listings[name];
        require(l.active, "Not listed");
        require(l.seller == msg.sender || msg.sender == owner, "Not the seller");

        l.active = false;
        registry.transfer(name, l.seller);

        emit Cancelled(l.seller, name);
    }

    /**
     * @notice Buy a listed name.
     *         Caller must approve this contract for `listing.price` USDC first.
     */
    function buy(string memory name) external {
        Listing storage l = _listings[name];
        require(l.active, "Not listed");
        require(l.seller != msg.sender, "Cannot buy your own listing");

        uint256 price  = l.price;
        uint256 fee    = (price * FEE_BPS) / BPS;
        uint256 payout = price - fee;

        // Mark inactive before transfers (reentrancy guard)
        l.active = false;

        // Pull USDC from buyer
        bool ok = usdc.transferFrom(msg.sender, address(this), price);
        require(ok, "USDC transfer failed");

        // Pay seller
        usdc.transfer(l.seller, payout);

        // Transfer name from this contract to buyer
        registry.transfer(name, msg.sender);

        emit Sold(l.seller, msg.sender, name, price, fee);
    }

    // ── Views ─────────────────────────────────

    /// @notice Get listing details for a name
    function getListing(string memory name) external view returns (
        address seller,
        uint256 price,
        uint256 listedAt,
        bool    active
    ) {
        Listing storage l = _listings[name];
        return (l.seller, l.price, l.listedAt, l.active);
    }

    /// @notice Get all active listings (paginated)
    function getActiveListings(uint256 offset, uint256 limit)
        external view returns (
            string[] memory names,
            address[] memory sellers,
            uint256[] memory prices,
            uint256[] memory listedAts
        )
    {
        // Count active first
        uint256 total = 0;
        for (uint256 i = 0; i < _listedNames.length; i++) {
            if (_listings[_listedNames[i]].active) total++;
        }

        uint256 end = offset + limit > total ? total : offset + limit;
        uint256 size = end > offset ? end - offset : 0;

        names     = new string[](size);
        sellers   = new address[](size);
        prices    = new uint256[](size);
        listedAts = new uint256[](size);

        uint256 idx = 0;
        uint256 active = 0;
        for (uint256 i = 0; i < _listedNames.length && idx < size; i++) {
            string memory n = _listedNames[i];
            if (_listings[n].active) {
                if (active >= offset) {
                    names[idx]     = n;
                    sellers[idx]   = _listings[n].seller;
                    prices[idx]    = _listings[n].price;
                    listedAts[idx] = _listings[n].listedAt;
                    idx++;
                }
                active++;
            }
        }
    }

    /// @notice Total active listing count
    function getListingCount() external view returns (uint256 count) {
        for (uint256 i = 0; i < _listedNames.length; i++) {
            if (_listings[_listedNames[i]].active) count++;
        }
    }

    // ── Admin ─────────────────────────────────

    /// @notice Withdraw accumulated protocol fees
    function withdrawFees() external onlyOwner {
        uint256 bal = usdc.balanceOf(address(this));
        require(bal > 0, "Nothing to withdraw");
        usdc.transfer(owner, bal);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        owner = newOwner;
    }
}

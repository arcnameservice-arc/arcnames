// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ─────────────────────────────────────────────
//  Minimal ERC-20 interface (USDC on Arc)
//  USDC ERC-20: 0x3600000000000000000000000000000000000000
//  Decimals: 6
// ─────────────────────────────────────────────
interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

/**
 * @title  ArcNameRegistry
 * @notice .arc name service registry on Arc Testnet.
 *         Users pay USDC (ERC-20, 6 decimals) to register a name for 1–5 years.
 *         Names are lowercase alphanumeric + hyphens, 2–32 chars.
 *
 * Pricing (per year, in USDC with 6 decimals):
 *   2 chars  → $50   = 50_000_000
 *   3 chars  → $20   = 20_000_000
 *   4 chars  → $10   = 10_000_000
 *   5+ chars → $2    =  2_000_000
 */
contract ArcNameRegistry {

    // ── Constants ─────────────────────────────
    IERC20 public immutable usdc;
    address public owner;

    uint256 public constant PRICE_2  = 50_000_000;  // $50 USDC (6 decimals)
    uint256 public constant PRICE_3  = 20_000_000;  // $20 USDC
    uint256 public constant PRICE_4  = 10_000_000;  // $10 USDC
    uint256 public constant PRICE_5P =  2_000_000;  //  $2 USDC

    uint256 public constant YEAR_SECONDS = 365 days;
    uint256 public constant MAX_YEARS    = 5;

    // ── Storage ───────────────────────────────
    struct NameRecord {
        address owner;
        uint256 expiry;       // unix timestamp
        uint256 registeredAt;
    }

    mapping(string  => NameRecord)  private _records;       // name → record
    mapping(address => string[])    private _ownedNames;    // wallet → names[]
    mapping(address => string)      private _primaryName;   // wallet → primary name

    // ── Events ────────────────────────────────
    event Registered(address indexed owner, string name, uint256 numYears, uint256 expiry, uint256 paid);
    event Renewed(address indexed owner, string name, uint256 numYears, uint256 newExpiry, uint256 paid);
    event Transferred(address indexed from, address indexed to, string name);
    event PrimarySet(address indexed owner, string name);
    event Withdrawn(address indexed to, uint256 amount);

    // ── Constructor ───────────────────────────
    constructor(address _usdc) {
        usdc  = IERC20(_usdc);
        owner = msg.sender;
    }

    // ── Modifiers ─────────────────────────────
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier validName(string memory name) {
        bytes memory b = bytes(name);
        uint256 len = b.length;
        require(len >= 2 && len <= 32, "Name length must be 2-32 chars");
        require(b[0] != '-' && b[len - 1] != '-', "Name cannot start/end with hyphen");
        for (uint256 i = 0; i < len; i++) {
            bytes1 c = b[i];
            bool isLower   = (c >= 0x61 && c <= 0x7A); // a-z
            bool isDigit   = (c >= 0x30 && c <= 0x39); // 0-9
            bool isHyphen  = (c == 0x2D);               // -
            require(isLower || isDigit || isHyphen, "Invalid character: use a-z, 0-9, -");
        }
        _;
    }

    // ── View helpers ──────────────────────────

    /// @notice Annual price in USDC (6 decimals) for a given name length
    function getYearlyPrice(string memory name) public pure returns (uint256) {
        uint256 len = bytes(name).length;
        if (len == 2) return PRICE_2;
        if (len == 3) return PRICE_3;
        if (len == 4) return PRICE_4;
        return PRICE_5P;
    }

    /// @notice Total cost for registering a name for `numYears` years
    function getPrice(string memory name, uint256 numYears) public pure returns (uint256) {
        require(numYears >= 1 && numYears <= MAX_YEARS, "Years must be 1-5");
        return getYearlyPrice(name) * numYears;
    }

    /// @notice Check if a name is available (not registered or expired)
    function isAvailable(string memory name) public view returns (bool) {
        NameRecord storage r = _records[name];
        return r.owner == address(0) || block.timestamp > r.expiry;
    }

    /// @notice Get full record for a name
    function getRecord(string memory name) external view returns (
        address nameOwner,
        uint256 expiry,
        uint256 registeredAt,
        bool    available
    ) {
        NameRecord storage r = _records[name];
        return (r.owner, r.expiry, r.registeredAt, isAvailable(name));
    }

    /// @notice Get all names owned by a wallet
    function getNamesOf(address wallet) external view returns (string[] memory) {
        return _ownedNames[wallet];
    }

    /// @notice Get primary name for a wallet
    function getPrimaryName(address wallet) external view returns (string memory) {
        return _primaryName[wallet];
    }

    /// @notice Resolve a name to its owner address
    function resolve(string memory name) external view returns (address) {
        NameRecord storage r = _records[name];
        if (block.timestamp > r.expiry) return address(0);
        return r.owner;
    }

    // ── Write functions ───────────────────────

    /**
     * @notice Register a name for 1-5 years.
     *         Caller must first approve this contract to spend USDC.
     * @param  name      The name to register (without .arc)
     * @param  numYears  Registration duration in years (1-5)
     */
    function register(string memory name, uint256 numYears)
        external
        validName(name)
    {
        require(numYears >= 1 && numYears <= MAX_YEARS, "Years must be 1-5");
        require(isAvailable(name), "Name is already registered");

        uint256 cost = getPrice(name, numYears);
        require(
            usdc.allowance(msg.sender, address(this)) >= cost,
            "Insufficient USDC allowance — call approve() first"
        );

        bool ok = usdc.transferFrom(msg.sender, address(this), cost);
        require(ok, "USDC transfer failed");

        uint256 expiry = block.timestamp + (numYears * YEAR_SECONDS);

        _records[name] = NameRecord({
            owner:        msg.sender,
            expiry:       expiry,
            registeredAt: block.timestamp
        });

        _ownedNames[msg.sender].push(name);

        // Auto-set as primary if this is the wallet's first name
        if (bytes(_primaryName[msg.sender]).length == 0) {
            _primaryName[msg.sender] = name;
            emit PrimarySet(msg.sender, name);
        }

        emit Registered(msg.sender, name, numYears, expiry, cost);
    }

    /**
     * @notice Renew an existing name for 1-5 additional years.
     *         Anyone can pay to renew (e.g., on behalf of the owner).
     */
    function renew(string memory name, uint256 numYears) external validName(name) {
        require(numYears >= 1 && numYears <= MAX_YEARS, "Years must be 1-5");
        NameRecord storage r = _records[name];
        require(r.owner != address(0), "Name not registered");
        require(block.timestamp <= r.expiry, "Name has expired — register instead");

        uint256 cost = getPrice(name, numYears);
        require(
            usdc.allowance(msg.sender, address(this)) >= cost,
            "Insufficient USDC allowance"
        );

        bool ok = usdc.transferFrom(msg.sender, address(this), cost);
        require(ok, "USDC transfer failed");

        r.expiry += numYears * YEAR_SECONDS;

        emit Renewed(r.owner, name, numYears, r.expiry, cost);
    }

    /**
     * @notice Transfer a name to another address.
     *         Only the current owner can transfer.
     */
    function transfer(string memory name, address to) external {
        require(to != address(0), "Cannot transfer to zero address");
        NameRecord storage r = _records[name];
        require(r.owner == msg.sender, "Not the name owner");
        require(block.timestamp <= r.expiry, "Name has expired");

        // Remove from sender's list
        _removeFromOwned(msg.sender, name);

        // Update record owner
        r.owner = to;

        // Add to recipient's list
        _ownedNames[to].push(name);

        // Clear primary if transferred name was primary
        if (keccak256(bytes(_primaryName[msg.sender])) == keccak256(bytes(name))) {
            delete _primaryName[msg.sender];
        }

        emit Transferred(msg.sender, to, name);
    }

    /**
     * @notice Set a name as your primary name.
     *         You must own the name and it must not be expired.
     */
    function setPrimary(string memory name) external {
        NameRecord storage r = _records[name];
        require(r.owner == msg.sender, "Not the name owner");
        require(block.timestamp <= r.expiry, "Name has expired");
        _primaryName[msg.sender] = name;
        emit PrimarySet(msg.sender, name);
    }

    // ── Admin ─────────────────────────────────

    /// @notice Withdraw collected USDC fees to owner wallet
    function withdraw() external onlyOwner {
        uint256 bal = usdc.balanceOf(address(this));
        require(bal > 0, "Nothing to withdraw");
        bool ok = usdc.transfer(owner, bal);
        require(ok, "Withdraw failed");
        emit Withdrawn(owner, bal);
    }

    /// @notice Transfer contract ownership
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        owner = newOwner;
    }

    // ── Internal helpers ──────────────────────

    function _removeFromOwned(address wallet, string memory name) internal {
        string[] storage names = _ownedNames[wallet];
        for (uint256 i = 0; i < names.length; i++) {
            if (keccak256(bytes(names[i])) == keccak256(bytes(name))) {
                names[i] = names[names.length - 1];
                names.pop();
                break;
            }
        }
    }
}

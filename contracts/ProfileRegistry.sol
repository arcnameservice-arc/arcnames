// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRegistry {
    function getRecord(string memory name) external view returns (
        address nameOwner,
        uint256 expiry,
        uint256 registeredAt,
        bool    available
    );
}

/**
 * @title  ProfileRegistry
 * @notice On-chain text records for .arc names. Inspired by ENS EIP-634.
 *
 * Supported keys:
 *   display    — Display name
 *   bio        — Short biography
 *   url        — Website URL
 *   avatar     — Avatar URL or IPFS CID
 *   com.twitter — Twitter/X handle
 *   addr.eth   — Ethereum address mapping
 *   addr.btc   — Bitcoin address mapping
 *
 * Rules:
 *   - Only the current name owner (in ArcNameRegistry) can write records.
 *   - Anyone can read records.
 *   - Expired names cannot be updated until renewed.
 *   - Key length max 64 chars, value length max 512 chars.
 */
contract ProfileRegistry {

    IRegistry public immutable registry;

    // name → key → value
    mapping(string => mapping(string => string)) private _records;

    // name → list of keys set (for enumeration)
    mapping(string => string[]) private _keys;
    mapping(string => mapping(string => bool)) private _keyExists;

    event TextChanged(string indexed name, string indexed key, string value);

    constructor(address _registry) {
        registry = IRegistry(_registry);
    }

    // ── Modifiers ─────────────────────────────

    modifier onlyNameOwner(string memory name) {
        (address nameOwner, uint256 expiry,,) = registry.getRecord(name);
        require(nameOwner == msg.sender,   "Not the name owner");
        require(block.timestamp <= expiry, "Name has expired");
        _;
    }

    // ── Write ──────────────────────────────────

    /**
     * @notice Set a single text record for a name.
     * @param name  The .arc name (without extension)
     * @param key   Record key (e.g. "display", "bio", "url", "avatar", "com.twitter")
     * @param value Record value. Pass empty string "" to clear.
     */
    function setText(
        string memory name,
        string memory key,
        string memory value
    ) external onlyNameOwner(name) {
        require(bytes(key).length > 0 && bytes(key).length <= 64,    "Key: 1-64 chars");
        require(bytes(value).length <= 512,                           "Value: max 512 chars");

        _records[name][key] = value;

        if (!_keyExists[name][key]) {
            _keyExists[name][key] = true;
            _keys[name].push(key);
        }

        emit TextChanged(name, key, value);
    }

    /**
     * @notice Set multiple text records in a single transaction.
     * @param name   The .arc name
     * @param keys   Array of keys
     * @param values Array of values (same length as keys)
     */
    function setTexts(
        string memory name,
        string[] memory keys,
        string[] memory values
    ) external onlyNameOwner(name) {
        require(keys.length == values.length, "Length mismatch");
        require(keys.length <= 20,            "Max 20 fields per tx");

        for (uint256 i = 0; i < keys.length; i++) {
            require(bytes(keys[i]).length > 0 && bytes(keys[i]).length <= 64,  "Key: 1-64 chars");
            require(bytes(values[i]).length <= 512,                             "Value: max 512 chars");

            _records[name][keys[i]] = values[i];

            if (!_keyExists[name][keys[i]]) {
                _keyExists[name][keys[i]] = true;
                _keys[name].push(keys[i]);
            }

            emit TextChanged(name, keys[i], values[i]);
        }
    }

    // ── Read ──────────────────────────────────

    /// @notice Get a single text record
    function text(string memory name, string memory key)
        external view returns (string memory)
    {
        return _records[name][key];
    }

    /// @notice Get multiple text records in one call
    function texts(string memory name, string[] memory keys)
        external view returns (string[] memory values)
    {
        values = new string[](keys.length);
        for (uint256 i = 0; i < keys.length; i++) {
            values[i] = _records[name][keys[i]];
        }
    }

    /// @notice Get all keys that have been set for a name
    function getKeys(string memory name)
        external view returns (string[] memory)
    {
        return _keys[name];
    }

    /// @notice Get all keys and their values for a name (full profile)
    function getProfile(string memory name)
        external view returns (string[] memory keys, string[] memory values)
    {
        keys   = _keys[name];
        values = new string[](keys.length);
        for (uint256 i = 0; i < keys.length; i++) {
            values[i] = _records[name][keys[i]];
        }
    }
}

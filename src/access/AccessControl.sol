// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./IAccessControl.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow
 * enumerating role
 * members except through off-chain means by accessing the contract event logs.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 * @author cosimo.demedici.eth (https://github.com/ninfa-labs/nft-suite)
 * @author modified from OpenZeppelin Contracts v5.1.0 (access/AccessControl)
 */
abstract contract AccessControl is IAccessControl {
    struct RoleData {
        mapping(address account => bool) hasRole;
        bytes32 adminRole;
    }

    mapping(bytes32 role => RoleData) private _roles;

    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a {AccessControlUnauthorizedAccount} error including the required role.
     */
    modifier onlyRole(bytes32 role) {
        if (!hasRole(role, msg.sender)) {
            revert AccessControlUnauthorizedAccount(msg.sender, role);
        }
        _;
    }

    /// @inheritdoc IAccessControl
    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role].hasRole[account];
    }

    /// @inheritdoc IAccessControl
    function getRoleAdmin(bytes32 role) public view returns (bytes32) {
        return _roles[role].adminRole;
    }

    /// @inheritdoc IAccessControl
    function grantRole(bytes32 role, address account) external onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /// @inheritdoc IAccessControl
    function revokeRole(bytes32 role, address account) external onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /// @inheritdoc IAccessControl
    function renounceRole(bytes32 role) external {
        _revokeRole(role, msg.sender);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     *
     * @dev Inheriting contracts should call this function to set _DEFAULT_ADMIN_ROLE (in the constructor)
     * or any other custom roles.
     */
    function _grantRole(bytes32 role, address account) internal {
        // omit checking whether the account already has the role
        _roles[role].hasRole[account] = true;
        emit RoleGranted(role, account, msg.sender);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Private function without access restriction.
     */
    function _revokeRole(bytes32 role, address account) private {
        // omit checking whether the account already has the role
        _roles[role].hasRole[account] = false;
        emit RoleRevoked(role, account, msg.sender);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

error Unauthorized(address sender, bytes32 node);
error InvalidPrice(uint256 price);
error InvalidDuration(uint256 duration);
error DurationTooShort(uint256 duration);
error InvalidAddress(address addr);
error NameNotAvailable(string name);
error RegistrationPeriodNotStarted();
error InvalidName(string name);
error CommitmentTooNew(bytes32 commitment);
error CommitmentTooOld(bytes32 commitment);
error CommitmentAlreadyExists(bytes32 commitment);
error UnexpiredCommitmentExists(bytes32 commitment);
error InsufficientValue();
error ContractNotLive();
error OnlyControllerAllowed();
error RegistratonExpired();
error InvalidTokenId();
error ResolverRequiredWhenDataSupplied();
error RegistrationExpired();
error SelfApprovalNotAllowed();
error NotAuthorised();
error ResolverRequired();
error NotController();
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RentalPlatform {

    address public admin;

    constructor() {
        admin = msg.sender;
    }

    // 사용자 프로필
    struct UserProfile {
        uint trustScore;
        uint totalDeals;
        uint averageRating;
        bool isRegistered;
    }

    mapping(address => UserProfile) public userProfiles;

    // 자산 정보
    struct Asset {
        uint id;
        address owner;
        string category;
        string description;
        uint deposit;
        bool isAvailable;
        string imageHash;
    }

    mapping(uint => Asset) public assets;
    uint public assetCount;

    // 대여 계약 상태
    enum RentalStatus { Requested, Active, Completed, Cancelled }

    struct RentalContract {
        uint id;
        uint assetId;
        address lender;
        address renter;
        uint startDate;
        uint endDate;
        uint deposit;
        RentalStatus status;
    }

    mapping(uint => RentalContract) public rentalContracts;
    uint public contractCount;

    // 평가 리뷰
    struct RentalReview {
        uint contractId;
        address reviewer;
        address reviewee;
        uint score;
        string comment;
        string assetConditionHash;
    }

    mapping(uint => RentalReview[]) public reviewsByContract;

    // 사용자 등록
    function registerUser() public {
        require(!userProfiles[msg.sender].isRegistered, "Already registered");
        userProfiles[msg.sender] = UserProfile(100, 0, 100, true);
    }

    // 자산 등록
    function registerAsset(
        string memory category,
        string memory description,
        uint deposit,
        string memory imageHash
    ) public {
        require(userProfiles[msg.sender].isRegistered, "User not registered");

        assetCount++;
        assets[assetCount] = Asset(
            assetCount,
            msg.sender,
            category,
            description,
            deposit,
            true,
            imageHash
        );
    }
    
    function getReviewCount(uint contractId) public view returns (uint) {
        return reviewsByContract[contractId].length;
    }

    function deleteAsset(uint assetId) public {
        Asset storage asset = assets[assetId];
        require(asset.owner == msg.sender, "Only the owner can delete the asset");
        require(asset.isAvailable, "Asset is currently rented");
        
        delete assets[assetId]; // 해당 자산 삭제
    }

    // 대여 계약 생성
    function createRentalContract(uint assetId, uint startDate, uint endDate) public payable {
        Asset storage a = assets[assetId];
        require(a.isAvailable, "Asset not available");
        require(msg.value == a.deposit, "Incorrect deposit amount");

        contractCount++;
        rentalContracts[contractCount] = RentalContract(
            contractCount,
            assetId,
            a.owner,
            msg.sender,
            startDate,
            endDate,
            msg.value,
            RentalStatus.Requested
        );

        a.isAvailable = false;
    }

    // 대여 완료 처리 (렌더만 호출 가능)
    function completeRental(uint contractId) public {
        RentalContract storage rc = rentalContracts[contractId];
        require(msg.sender == rc.lender, "Only lender can complete rental");
        require(rc.status == RentalStatus.Requested, "Invalid status");

        rc.status = RentalStatus.Completed;
        payable(rc.renter).transfer(rc.deposit);

        assets[rc.assetId].isAvailable = true;

        userProfiles[rc.renter].totalDeals++;
        userProfiles[rc.lender].totalDeals++;
    }

    // 리뷰 남기기
    function leaveReview(
        uint contractId,
        address reviewee,
        uint score,
        string memory comment,
        string memory assetConditionHash
    ) public {
        require(score >= 1 && score <= 5, "Score must be 1-5");
        RentalContract storage rc = rentalContracts[contractId];
        require(rc.status == RentalStatus.Completed, "Contract not completed");
        require(msg.sender == rc.renter || msg.sender == rc.lender, "Not participant");

        reviewsByContract[contractId].push(RentalReview(
            contractId,
            msg.sender,
            reviewee,
            score,
            comment,
            assetConditionHash
        ));

        // 신뢰 점수 간단 반영
        UserProfile storage up = userProfiles[reviewee];
        up.averageRating = (up.averageRating * up.totalDeals + score) / (up.totalDeals + 1);
        up.trustScore = up.averageRating * 20;
    }
}

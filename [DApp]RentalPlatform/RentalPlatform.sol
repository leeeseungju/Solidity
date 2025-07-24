// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title RentalPlatform
 * @dev 사용자 간 자산을 대여하고, 계약 및 리뷰를 기록할 수 있는 DApp용 스마트컨트랙트
 */
contract RentalPlatform {

    // 플랫폼 관리자 주소
    address public admin;

    // 배포자(관리자) 설정
    constructor() {
        admin = msg.sender;
    }

    // 관리자 전용 함수 제한자
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    // 사용자 정보 구조체
    struct UserProfile {
        uint trustScore;        // 신뢰 점수
        uint totalDeals;        // 총 거래 횟수
        uint averageRating;     // 평균 평점
        bool isRegistered;      // 등록 여부
    }

    // 사용자 주소 → 프로필
    mapping(address => UserProfile) public userProfiles;

    // 자산 정보 구조체
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

    // 대여 상태 열거형
    enum RentalStatus { Requested, Active, Completed, Cancelled }

    // 대여 계약 구조체
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

    // 리뷰 구조체
    struct RentalReview {
        uint contractId;
        address reviewer;
        address reviewee;
        uint score;
        string comment;
        string assetConditionHash;
    }

    // 계약 ID → 리뷰 목록
    mapping(uint => RentalReview[]) public reviewsByContract;

    /**
     * @notice 사용자 등록 (최초 1회)
     */
    function registerUser() public {
        require(!userProfiles[msg.sender].isRegistered, "Already registered");
        userProfiles[msg.sender] = UserProfile(100, 0, 100, true);
    }

    /**
     * @notice 자산 등록 (등록된 사용자만 가능)
     */
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

    /**
     * @notice 자산 삭제 (자산 소유자만 가능, 현재 대여 중이 아니어야 함)
     */
    function deleteAsset(uint assetId) public {
        Asset storage asset = assets[assetId];
        require(asset.owner == msg.sender, "Only the owner can delete the asset");
        require(asset.isAvailable, "Asset is currently rented");

        delete assets[assetId];
    }

    /**
     * @notice 자산 비활성화 (관리자만 가능)
     */
    function deactivateAsset(uint assetId) public onlyAdmin {
        Asset storage asset = assets[assetId];
        require(asset.owner != address(0), "Asset does not exist");
        asset.isAvailable = false;
    }

    /**
     * @notice 자산 재활성화 (관리자만 가능)
     */
    function activateAsset(uint assetId) public onlyAdmin {
        Asset storage asset = assets[assetId];
        require(asset.owner != address(0), "Asset does not exist");
        asset.isAvailable = true;
    }

    /**
     * @notice 대여 계약 생성 (자산 대여 요청, deposit 필요)
     */
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

    /**
     * @notice 대여 완료 처리 (렌더만 가능, 보증금 반환)
     */
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

    /**
     * @notice 리뷰 작성 (계약 완료 후에만 가능, 참가자만 가능)
     */
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

        UserProfile storage up = userProfiles[reviewee];
        up.averageRating = (up.averageRating * up.totalDeals + score) / (up.totalDeals + 1);
        up.trustScore = up.averageRating * 20;
    }

    /**
     * @notice 특정 계약의 리뷰 수 조회
     */
    function getReviewCount(uint contractId) public view returns (uint) {
        return reviewsByContract[contractId].length;
    }
}

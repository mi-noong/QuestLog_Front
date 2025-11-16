import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'services/sound_manager.dart';
import 'HomeScreen.dart';

// 파티클 클래스
class Particle {
  double x;
  double y;
  double vx;
  double vy;
  Color color;
  double size;
  double life;
  double maxLife;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.life,
    required this.maxLife,
  });

  bool isAlive() => life > 0;

  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vy += 50 * dt; // 중력
    life -= dt;
  }
}

class BossRpgScreen extends StatefulWidget {
  const BossRpgScreen({super.key});

  @override
  State<BossRpgScreen> createState() => _BossRpgScreenState();
}

class _BossRpgScreenState extends State<BossRpgScreen> {
  // 드래그 컨트롤러 위치 (왼쪽 아래 기준)
  double _controllerX = 0.0;
  double _controllerY = 0.0;
  double _controllerRadius = 30.0; // 컨트롤러 원의 반지름
  double _maxDragDistance = 40.0; // 최대 드래그 거리

  // 스킬 버튼 위치 조정 (오른쪽 아래 기준)
  double _skillStabBottom = 125.0; // Skill_Stab 위치 (위에서부터)
  double _skillStabRight = 5.0; // Skill_Stab 왼쪽 위치 (오른쪽에서부터)
  double _skillBasicBottom = 20.0; // Skill_Basic 위치 (가운데)
  double _skillBasicRight = 10.0; // Skill_Basic 왼쪽 위치 (오른쪽에서부터)
  double _skillDashBottom = 5.0; // Skill_Dash 위치 (아래에서부터)
  double _skillDashRight = 110.0; // Skill_Dash 왼쪽 위치 (오른쪽에서부터)

  // 캐릭터 관련
  double _characterX = 0.0; // 캐릭터 X 위치 (화면 중앙 기준)
  String _currentWalkFrame = 'assets/images/rpg/Ch_Basic.png'; // 현재 걷기 프레임
  int _walkFrameIndex = 0; // 걷기 애니메이션 프레임 인덱스 (0-4)
  Timer? _characterUpdateTimer; // 걷기 애니메이션 타이머
  Timer? _characterMoveTimer; // 캐릭터 이동 타이머
  bool _isWalking = false; // 걷는 중인지 여부
  bool _isWalkingRight = true; // 오른쪽으로 걷는지 여부
  double _screenWidth = 0.0; // 화면 너비
  double _screenHeight = 0.0; // 화면 높이
  double _targetControllerX = 0.0; // 목표 컨트롤러 X 위치

  // 공격 애니메이션 관련
  bool _isAttacking = false; // 공격 중인지 여부
  int _fightFrameIndex = 0; // 공격 애니메이션 프레임 인덱스 (0-4)
  Timer? _fightAnimationTimer; // 공격 애니메이션 타이머

  // Stab 애니메이션 관련
  bool _isStabbing = false; // Stab 중인지 여부
  int _stabFrameIndex = 0; // Stab 애니메이션 프레임 인덱스 (0-3)
  Timer? _stabAnimationTimer; // Stab 애니메이션 타이머
  bool _stabOnCooldown = false; // Stab 쿨타임 중인지 여부
  Timer? _stabCooldownTimer; // Stab 쿨타임 타이머
  double _stabCooldownRemaining = 0.0; // Stab 쿨타임 남은 시간 (초)
  Timer? _stabCooldownUpdateTimer; // Stab 쿨타임 업데이트 타이머
  bool _lastAttackWasStab = false; // 마지막 공격이 Stab인지 여부 (데미지 구분용)

  // 대시 관련
  bool _isDashing = false; // 대시 중인지 여부
  double _dashDistance = 0.0; // 대시한 거리
  double _dashTotalDistance = 125.0; // 총 대시 거리 (250의 절반)
  Timer? _dashTimer; // 대시 타이머
  bool _dashOnCooldown = false; // 대시 쿨타임 중인지 여부
  Timer? _dashCooldownTimer; // 대시 쿨타임 타이머
  double _dashCooldownRemaining = 0.0; // 대시 쿨타임 남은 시간 (초)
  Timer? _dashCooldownUpdateTimer; // 대시 쿨타임 업데이트 타이머

  // 피격 애니메이션 관련
  bool _isAttacked = false; // 피격 중인지 여부
  Timer? _attackedAnimationTimer; // 피격 애니메이션 타이머
  bool _isSpeedReduced = false; // 속도 감소 상태 (공격 1)
  Timer? _speedReducedTimer; // 속도 감소 타이머
  bool _isStunned = false; // 정지 상태 (공격 2)
  Timer? _stunnedTimer; // 정지 타이머
  double _characterKnockbackX = 0.0; // 캐릭터 튕겨짐 X 오프셋 (공격 3)
  Timer? _characterKnockbackTimer; // 캐릭터 튕겨짐 타이머
  double _characterMoveSpeed = 3.0; // 캐릭터 기본 이동 속도

  // 죽음 애니메이션 관련
  bool _isDead = false; // 죽음 상태인지 여부
  int _deathFrameIndex = 0; // 죽음 애니메이션 프레임 인덱스 (0-3)
  Timer? _deathAnimationTimer; // 죽음 애니메이션 타이머

  // 몬스터 관련
  double _monsterX = 0.0; // 몬스터 X 위치 (화면 중앙 기준)
  double _monsterY = 0.0; // 몬스터 Y 오프셋 (점프 효과용)
  String _monsterFrame = 'assets/images/rpg/Boss_Idle.png'; // 현재 몬스터 프레임 (왼쪽을 보는 상태)
  int _monsterWalkFrameIndex = 0; // 몬스터 걷기 애니메이션 프레임 인덱스 (0-5)
  bool _monsterFacingRight = false; // 몬스터가 오른쪽을 보고 있는지 여부 (초기값: 왼쪽)
  Timer? _monsterUpdateTimer; // 몬스터 업데이트 타이머
  double _monsterMoveSpeed = 2.0; // 몬스터 이동 속도
  double _attackRange = 140.0; // 공격 범위 (기본값, 패턴별로 변경됨)
  int _monsterFrameCounter = 0; // 몬스터 애니메이션 프레임 카운터
  bool _monsterIsResting = false; // 몬스터가 휴식 중인지 여부
  Timer? _monsterRestTimer; // 몬스터 휴식 타이머
  double _monsterOriginalX = 0.0; // 몬스터 원래 위치 (공격2 점프 후 복귀용)

  // 몬스터 공격 관련
  bool _monsterIsAttacking = false; // 몬스터가 공격 중인지 여부
  bool _monsterIsPreparing = false; // 몬스터가 전조 모션 중인지 여부
  int _monsterAttackPattern = 1; // 현재 공격 패턴 (1, 2, 3)
  int _monsterAttackFrameIndex = 0; // 공격 애니메이션 프레임 인덱스
  int _monsterPreparingFrameIndex = 0; // 전조 모션 프레임 인덱스
  Timer? _monsterAttackTimer; // 몬스터 공격 타이머
  Timer? _monsterPreparingTimer; // 몬스터 전조 모션 타이머
  bool _isComboAttack = false; // 연속 공격 중인지 여부
  int _comboAttackCount = 0; // 연속 공격 횟수
  int _comboType = 0; // 연속 공격 타입 (1: 연속공격1, 2: 2*3공격)
  double _monsterSpeedMultiplier = 1.0; // 몬스터 속도 배율 (30% 이하일 때 증가)
  double _monsterAttackSpeedMultiplier = 1.0; // 몬스터 공격 속도 배율 (30% 이하일 때 증가)

  // 몬스터 피격 관련
  bool _monsterIsHurt = false; // 몬스터가 피격 중인지 여부
  Timer? _monsterHurtTimer; // 몬스터 피격 타이머
  double _monsterKnockbackX = 0.0; // 몬스터 뒤로 밀려나는 X 오프셋
  Timer? _monsterKnockbackTimer; // 몬스터 밀려남 애니메이션 타이머
  List<Particle> _hitParticles = []; // 피격 파티클 리스트
  Timer? _particleUpdateTimer; // 파티클 업데이트 타이머

  // 몬스터 죽음 애니메이션 관련
  bool _monsterIsDead = false; // 몬스터 죽음 상태인지 여부
  int _monsterDeathFrameIndex = 0; // 몬스터 죽음 애니메이션 프레임 인덱스 (0-3)
  Timer? _monsterDeathAnimationTimer; // 몬스터 죽음 애니메이션 타이머

  // 종료 확인 다이얼로그 관련
  bool _showExitDialog = false; // 종료 확인 다이얼로그 표시 여부

  // 보상 다이얼로그 관련
  bool _showRewardDialog = false; // 보상 다이얼로그 표시 여부
  bool _isChestClosed = true; // 보물상자가 닫혀 있는지 여부
  bool _isChestAnimating = false; // 보물상자 애니메이션 중인지 여부
  String? _rewardPetAsset; // 획득한 펫 이미지 경로 (없으면 null)
  double _chestShakeX = 0.0; // 보물상자 흔들림 X 오프셋
  double _chestShakeY = 0.0; // 보물상자 흔들림 Y 오프셋
  bool _isEggAnimating = false; // Egg 애니메이션 중인지 여부
  int _eggAnimationFrame = 0; // Egg 애니메이션 프레임 (1~4)
  String? _hatchedPetAsset; // 부화한 펫 이미지 경로 (Pet_Cat, Pet_Dog, Pet_Rabbit)
  Timer? _eggAnimationTimer; // Egg 애니메이션 타이머

  // 실패 다이얼로그 관련
  bool _showFailureDialog = false; // 실패 다이얼로그 표시 여부

  // 게임 시작 관련
  bool _gameStarted = false; // 게임이 시작되었는지 여부

  // 이미지 프리로딩 및 캐싱
  final Map<String, ImageProvider> _imageCache = {};
  double _cachedScreenWidth = 0.0;

  // 사용자 스탯
  int _playerAttack = 15; // 공격력
  int _playerDefense = 10; // 방어력
  int _playerHealth = 200; // 체력
  int _playerMaxHealth = 200; // 최대 체력

  // 몬스터 스탯
  int _monsterAttack = 40; // 공격력
  int _monsterHealth = 500; // 체력
  int _monsterMaxHealth = 500; // 최대 체력

  @override
  void initState() {
    super.initState();
    // 가로 모드로 고정
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // 이미지 프리로딩 (첫 프레임 후 실행)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadImages();
      // 캐릭터 및 몬스터 초기 위치 설정
      if (mounted) {
        final screenWidth = MediaQuery.of(context).size.width;
        setState(() {
          // 캐릭터 초기 위치 (왼쪽)
          _characterX = -screenWidth * 0.52; // 왼쪽에 배치 (화면 중앙 기준 왼쪽으로 35%)

          // 몬스터 초기 위치 (오른쪽 끝)
          _monsterX = screenWidth * 0.65; // 오른쪽 끝 위치
          _monsterOriginalX = _monsterX; // 원래 위치 저장
          _monsterFrame = 'assets/images/rpg/Boss_Idle.png'; // 왼쪽을 보는 대기 상태
          _monsterFacingRight = false; // 왼쪽을 보고 있음
        });

        // 게임 시작 전까지는 정지 상태
        _gameStarted = false;
        _monsterIsResting = true; // 게임 시작 전까지 휴식 상태
      }
      // 게임 시작 전까지는 몬스터 업데이트 시작하지 않음
      
      // 보스 스테이지 배경음악 재생
      SoundManager().playBossStageMusic();
    });
  }

  // 이미지 프리로딩
  void _preloadImages() async {
    if (!mounted) return;

    final images = [
      'assets/images/rpg/Ch_Basic.png',
      'assets/images/rpg/Ch_Basic_Reverse.png',
      'assets/images/rpg/Ch_Walk_01.png',
      'assets/images/rpg/Ch_Walk_02.png',
      'assets/images/rpg/Ch_Walk_03.png',
      'assets/images/rpg/Ch_Walk_04.png',
      'assets/images/rpg/Ch_Walk_05.png',
      'assets/images/rpg/Ch_Walk_Reverse_01.png',
      'assets/images/rpg/Ch_Walk_Reverse_02.png',
      'assets/images/rpg/Ch_Walk_Reverse_03.png',
      'assets/images/rpg/Ch_Walk_Reverse_04.png',
      'assets/images/rpg/Ch_Walk_Reverse_05.png',
      'assets/images/rpg/Ch_Fight_01.png',
      'assets/images/rpg/Ch_Fight_02.png',
      'assets/images/rpg/Ch_Fight_03.png',
      'assets/images/rpg/Ch_Fight_04.png',
      'assets/images/rpg/Ch_Fight_05.png',
      'assets/images/rpg/Ch_Fight_Reverse_01.png',
      'assets/images/rpg/Ch_Fight_Reverse_02.png',
      'assets/images/rpg/Ch_Fight_Reverse_03.png',
      'assets/images/rpg/Ch_Fight_Reverse_04.png',
      'assets/images/rpg/Ch_Fight_Reverse_05.png',
      'assets/images/rpg/Ch_Stab_1.png',
      'assets/images/rpg/Ch_Stab_2.png',
      'assets/images/rpg/Ch_Stab_3.png',
      'assets/images/rpg/Ch_Stab_4.png',
      'assets/images/rpg/Ch_Stab_Reverse_1.png',
      'assets/images/rpg/Ch_Stab_Reverse_2.png',
      'assets/images/rpg/Ch_Stab_Reverse_3.png',
      'assets/images/rpg/Ch_Stab_Reverse_4.png',
      // 캐릭터 피격 이미지
      'assets/images/rpg/Ch_Attacked.png',
      'assets/images/rpg/Ch_Attacked_Reverse.png',
      // 캐릭터 죽음 이미지
      'assets/images/rpg/Ch_Died_01.png',
      'assets/images/rpg/Ch_Died_02.png',
      'assets/images/rpg/Ch_Died_03.png',
      'assets/images/rpg/Ch_Died_04.png',
      'assets/images/rpg/Ch_Died_Reverse_01.png',
      'assets/images/rpg/Ch_Died_Reverse_02.png',
      'assets/images/rpg/Ch_Died_Reverse_03.png',
      'assets/images/rpg/Ch_Died_Reverse_04.png',
      // 몬스터 이미지
      'assets/images/rpg/Boss_Idle.png',
      'assets/images/rpg/Boss_Idle_Reverse.png',
      'assets/images/rpg/Boss_Walk_1.png',
      'assets/images/rpg/Boss_Walk_2.png',
      'assets/images/rpg/Boss_Walk_3.png',
      'assets/images/rpg/Boss_Walk_4.png',
      'assets/images/rpg/Boss_Walk_5.png',
      'assets/images/rpg/Boss_Walk_6.png',
      'assets/images/rpg/Boss_Walk_Reverse_1.png',
      'assets/images/rpg/Boss_Walk_Reverse_2.png',
      'assets/images/rpg/Boss_Walk_Reverse_3.png',
      'assets/images/rpg/Boss_Walk_Reverse_4.png',
      'assets/images/rpg/Boss_Walk_Reverse_5.png',
      'assets/images/rpg/Boss_Walk_Reverse_6.png',
      // 몬스터 공격 이미지
      'assets/images/rpg/Boss_Attack1_1.png',
      'assets/images/rpg/Boss_Attack1_2.png',
      'assets/images/rpg/Boss_Attack1_3.png',
      'assets/images/rpg/Boss_Attack1_4.png',
      'assets/images/rpg/Boss_Attack1_Reverse_1.png',
      'assets/images/rpg/Boss_Attack1_Reverse_2.png',
      'assets/images/rpg/Boss_Attack1_Reverse_3.png',
      'assets/images/rpg/Boss_Attack1_Reverse_4.png',
      'assets/images/rpg/Boss_Attack2_1.png',
      'assets/images/rpg/Boss_Attack2_2.png',
      'assets/images/rpg/Boss_Attack2_3.png',
      'assets/images/rpg/Boss_Attack2_4.png',
      'assets/images/rpg/Boss_Attack2_Reverse_1.png',
      'assets/images/rpg/Boss_Attack2_Reverse_2.png',
      'assets/images/rpg/Boss_Attack2_Reverse_3.png',
      'assets/images/rpg/Boss_Attack2_Reverse_4.png',
      'assets/images/rpg/Boss_Attack3_1.png',
      'assets/images/rpg/Boss_Attack3_2.png',
      'assets/images/rpg/Boss_Attack3_3.png',
      'assets/images/rpg/Boss_Attack3_4.png',
      'assets/images/rpg/Boss_Attack3_5.png',
      'assets/images/rpg/Boss_Attack3_6.png',
      'assets/images/rpg/Boss_Attack3_Reverse_1.png',
      'assets/images/rpg/Boss_Attack3_Reverse_2.png',
      'assets/images/rpg/Boss_Attack3_Reverse_3.png',
      'assets/images/rpg/Boss_Attack3_Reverse_4.png',
      'assets/images/rpg/Boss_Attack3_Reverse_5.png',
      'assets/images/rpg/Boss_Attack3_Reverse_6.png',
      // 몬스터 피격 이미지
      'assets/images/rpg/Boss_Hurt.png',
      'assets/images/rpg/Boss_Hurt_Reverse.png',
      // 몬스터 죽음 이미지
      'assets/images/rpg/Boss_Death_1.png',
      'assets/images/rpg/Boss_Death_2.png',
      'assets/images/rpg/Boss_Death_3.png',
      'assets/images/rpg/Boss_Death_4.png',
      'assets/images/rpg/Boss_Death_Reverse_1.png',
      'assets/images/rpg/Boss_Death_Reverse_2.png',
      'assets/images/rpg/Boss_Death_Reverse_3.png',
      'assets/images/rpg/Boss_Death_Reverse_4.png',
      // 보상 이미지
      'assets/images/Close_TreasureChest_RPG.png',
      'assets/images/Open_TreasureChest_RPG.png',
      'assets/images/rpg/Egg_cat_1.png',
      'assets/images/rpg/Egg_cat_2.png',
      'assets/images/rpg/Egg_cat_3.png',
      'assets/images/rpg/Egg_cat_4.png',
      'assets/images/rpg/Egg_dog_1.png',
      'assets/images/rpg/Egg_dog_2.png',
      'assets/images/rpg/Egg_dog_3.png',
      'assets/images/rpg/Egg_dog_4.png',
      'assets/images/rpg/Egg_rabbit_1.png',
      'assets/images/rpg/Egg_rabbit_2.png',
      'assets/images/rpg/Egg_rabbit_3.png',
      'assets/images/rpg/Egg_rabbit_4.png',
      'assets/images/Pet_Cat.png',
      'assets/images/Pet_Dog.png',
      'assets/images/Pet_Rabbit.png',
    ];

    // 모든 이미지를 순차적으로 프리로드 (완전히 로드될 때까지 대기)
    for (final imagePath in images) {
      if (!mounted) break;
      final provider = AssetImage(imagePath);
      _imageCache[imagePath] = provider;
      // 이미지 프리로드 및 완료 대기
      try {
        await precacheImage(provider, context);
      } catch (e) {
        print('⚠️ 이미지 프리로드 실패: $imagePath - $e');
      }
    }
  }

  @override
  void dispose() {
    // 타이머 정리
    _characterUpdateTimer?.cancel();
    _characterMoveTimer?.cancel();
    _fightAnimationTimer?.cancel();
    _stabAnimationTimer?.cancel();
    _dashTimer?.cancel();
    _dashCooldownTimer?.cancel();
    _dashCooldownUpdateTimer?.cancel();
    _stabCooldownTimer?.cancel();
    _stabCooldownUpdateTimer?.cancel();
    _attackedAnimationTimer?.cancel();
    _speedReducedTimer?.cancel();
    _stunnedTimer?.cancel();
    _characterKnockbackTimer?.cancel();
    _deathAnimationTimer?.cancel();
    _monsterUpdateTimer?.cancel();
    _monsterAttackTimer?.cancel();
    _monsterPreparingTimer?.cancel();
    _monsterHurtTimer?.cancel();
    _monsterKnockbackTimer?.cancel();
    _particleUpdateTimer?.cancel();
    _monsterRestTimer?.cancel();
    _monsterDeathAnimationTimer?.cancel();
    _eggAnimationTimer?.cancel();
    // 배경음악 정지
    SoundManager().stopBossStageMusic();
    // 화면을 떠날 때 모든 방향 허용으로 복원
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 화면 크기 저장 (변경되었을 때만 업데이트)
    final currentWidth = MediaQuery.of(context).size.width;
    final currentHeight = MediaQuery.of(context).size.height;
    if ((currentWidth - _cachedScreenWidth).abs() > 1.0) {
      _screenWidth = currentWidth;
      _cachedScreenWidth = currentWidth;
    }
    _screenHeight = currentHeight;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/rpg/Background_Boss.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // 캐릭터 HP바 (오른쪽으로 살짝 이동)
              Positioned(
                top: 10,
                left: 70, // BackButton 옆에 배치
                child: RepaintBoundary(
                  child: _buildHpBar(_playerHealth, _playerMaxHealth),
                ),
              ),

              // 몬스터 HP바 (왼쪽으로 살짝 이동)
              Positioned(
                top: 10,
                right: 50, // 오른쪽에서 살짝 왼쪽으로
                child: RepaintBoundary(
                  child: _buildHpBar(_monsterHealth, _monsterMaxHealth),
                ),
              ),

              // 죽음 상태가 아닐 때: 캐릭터 -> 몬스터 순서 (캐릭터가 뒤에)
              if (!_isDead) ...[
                // 캐릭터 (RepaintBoundary로 분리하여 불필요한 리빌드 방지)
                Positioned(
                  bottom: _currentWalkFrame.contains('Ch_Died') ? 0 : (_currentWalkFrame.contains('Ch_Stab') ? 12.5 : 40),
                  // 죽음 애니메이션일 때는 더 아래로 (0), Stab일 때는 크기가 커져서 bottom 위치 조정, 일반적으로 더 아래로 (100 -> 70, 72.5 -> 42.5)
                  left: _screenWidth / 2 + _characterX + _characterKnockbackX - (_currentWalkFrame.contains('Ch_Stab') ? 110.0 : 82.5), // Stab일 때는 더 큰 크기 고려 (220/2) + 튕겨짐 오프셋
                  child: RepaintBoundary(
                    child: _buildCharacter(),
                  ),
                ),

                // 몬스터 (RepaintBoundary로 분리)
                Positioned(
                  bottom: 40 + _monsterY - _getMonsterBottomOffset(), // 캐릭터와 같은 높이 + 점프 오프셋 - 크기 보정
                  left: _screenWidth / 2 + _monsterX + _monsterKnockbackX - _getMonsterWidth() / 2, // 몬스터 중앙 기준 + 밀려남 오프셋
                  child: RepaintBoundary(
                    child: _buildMonster(),
                  ),
                ),
              ] else ...[
                // 죽음 상태일 때: 몬스터 -> 캐릭터 순서 (캐릭터가 앞에)
                // 몬스터 (RepaintBoundary로 분리)
                Positioned(
                  bottom: 40 + _monsterY - _getMonsterBottomOffset(), // 캐릭터와 같은 높이 + 점프 오프셋 - 크기 보정
                  left: _screenWidth / 2 + _monsterX + _monsterKnockbackX - _getMonsterWidth() / 2, // 몬스터 중앙 기준 + 밀려남 오프셋
                  child: RepaintBoundary(
                    child: _buildMonster(),
                  ),
                ),

                // 캐릭터 (RepaintBoundary로 분리하여 불필요한 리빌드 방지)
                Positioned(
                  bottom: _currentWalkFrame.contains('Ch_Died') ? 0 : (_currentWalkFrame.contains('Ch_Stab') ? 12.5 : 40),
                  // 죽음 애니메이션일 때는 더 아래로 (0), Stab일 때는 크기가 커져서 bottom 위치 조정, 일반적으로 더 아래로 (100 -> 70, 72.5 -> 42.5)
                  left: _screenWidth / 2 + _characterX + _characterKnockbackX - (_currentWalkFrame.contains('Ch_Stab') ? 110.0 : 82.5), // Stab일 때는 더 큰 크기 고려 (220/2) + 튕겨짐 오프셋
                  child: RepaintBoundary(
                    child: _buildCharacter(),
                  ),
                ),
              ],

              // 파티클 이펙트
              CustomPaint(
                painter: ParticlePainter(_hitParticles),
                size: Size.infinite,
              ),

              // 종료 확인 다이얼로그
              if (_showExitDialog)
                _buildExitDialog(),

              // 보상 다이얼로그
              if (_showRewardDialog)
                _buildRewardDialog(),

              // 실패 다이얼로그
              if (_showFailureDialog)
                _buildFailureDialog(),

              // 시작 버튼 (게임 시작 전에만 표시)
              if (!_gameStarted)
                _buildStartButton(),

              // 뒤로가기 버튼 (다이얼로그 위에 표시되도록 마지막에 배치)
              Positioned(
                top: 10,
                left: 10,
                child: GestureDetector(
                  onTap: () {
                    if (!_showExitDialog) {
                      SoundManager().playClick();
                      _showExitConfirmationDialog();
                    }
                  },
                  child: Image.asset(
                    'assets/images/BackButton.png',
                    width: 45,
                    height: 45,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // 왼쪽 아래 끝: 드래그 컨트롤러 (RepaintBoundary로 분리)
              Positioned(
                bottom: 20,
                left: 20,
                child: RepaintBoundary(
                  child: _buildDragController(),
                ),
              ),

              // 스킬 버튼들 (위치 조정 가능)
              Positioned(
                bottom: _skillStabBottom,
                right: _skillStabRight,
                child: GestureDetector(
                  onTap: () {
                    if (!_stabOnCooldown) {
                      // Stab 애니메이션 시작
                      _startStabAnimation();
                    }
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: _stabOnCooldown ? 0.4 : 1.0,
                        child: Image.asset(
                          'assets/images/rpg/Skill_Stab.png',
                          width: 60,
                          height: 60,
                          fit: BoxFit.contain,
                        ),
                      ),
                      if (_stabOnCooldown)
                        Text(
                          _stabCooldownRemaining.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 4,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: _skillBasicBottom,
                right: _skillBasicRight,
                child: GestureDetector(
                  onTap: () {
                    // 공격 애니메이션 시작
                    _startFightAnimation();
                  },
                  child: Image.asset(
                    'assets/images/rpg/Skill_Basic.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                bottom: _skillDashBottom,
                right: _skillDashRight,
                child: GestureDetector(
                  onTap: () {
                    if (!_dashOnCooldown) {
                      // 대시 기능 시작
                      _startDash();
                    }
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: _dashOnCooldown ? 0.4 : 1.0,
                        child: Image.asset(
                          'assets/images/rpg/Skill_Dash.png',
                          width: 60,
                          height: 60,
                          fit: BoxFit.contain,
                        ),
                      ),
                      if (_dashOnCooldown)
                        Text(
                          _dashCooldownRemaining.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 4,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 종료 확인 다이얼로그 표시
  void _showExitConfirmationDialog() {
    // 모든 타이머 중지
    _pauseAllTimers();
    
    setState(() {
      _showExitDialog = true;
    });
  }

  // 모든 타이머 일시 정지
  void _pauseAllTimers() {
    _characterUpdateTimer?.cancel();
    _characterMoveTimer?.cancel();
    _fightAnimationTimer?.cancel();
    _stabAnimationTimer?.cancel();
    _dashTimer?.cancel();
    _attackedAnimationTimer?.cancel();
    _monsterUpdateTimer?.cancel();
    _monsterAttackTimer?.cancel();
    _monsterPreparingTimer?.cancel();
    _monsterHurtTimer?.cancel();
    _monsterKnockbackTimer?.cancel();
    _monsterRestTimer?.cancel();
    _monsterDeathAnimationTimer?.cancel();
  }

  // 모든 타이머 재개
  void _resumeAllTimers() {
    // 캐릭터가 죽지 않았고 몬스터가 죽지 않았으면 타이머 재개
    if (!_isDead && !_monsterIsDead) {
      if (_isWalking && _targetControllerX != 0) {
        _startCharacterUpdate();
      }
      _startMonsterUpdate();
    }
  }

  // 시작 버튼 위젯
  Widget _buildStartButton() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.3), // 약간 어두운 배경
        child: Center(
          child: GestureDetector(
            onTap: () {
              SoundManager().playClick();
              // 게임 시작
              setState(() {
                _gameStarted = true;
              });
              // 몬스터 처음 생성 시 3초 휴식
              _monsterIsResting = true;
              _monsterRestTimer?.cancel();
              _monsterRestTimer = Timer(const Duration(milliseconds: 3000), () {
                if (mounted) {
                  setState(() {
                    _monsterIsResting = false;
                  });
                }
              });
              // 몬스터 업데이트 시작
              _startMonsterUpdate();
            },
            child: Image.asset(
              'assets/images/rpg/Startbutton.png',
              width: 450,
              height: 250,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  // 종료 확인 다이얼로그 위젯
  Widget _buildExitDialog() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.5), // 반투명 배경
        child: Center(
          child: Container(
            width: 450,
            height: 250,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/StoreItemFrame_row.png'),
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '보스 스테이지를 종료하시겠습니까?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 6,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 50),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 예 버튼
                    GestureDetector(
                      onTap: () {
                        SoundManager().playClick();
                        // HomeScreen으로 이동
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const HomeScreen()),
                        );
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            'assets/images/MainButton.png',
                            width: 140,
                            height: 70,
                            fit: BoxFit.contain,
                          ),
                          const Text(
                            '예',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),
                    // 아니오 버튼
                    GestureDetector(
                      onTap: () {
                        SoundManager().playClick();
                        // 다이얼로그 닫기 및 타이머 재개
                        setState(() {
                          _showExitDialog = false;
                        });
                        _resumeAllTimers();
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            'assets/images/MainButton.png',
                            width: 140,
                            height: 70,
                            fit: BoxFit.contain,
                          ),
                          const Text(
                            '아니오',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 드래그 컨트롤러 위젯
  Widget _buildDragController() {
    return GestureDetector(
      onPanUpdate: (details) {
        // 게임이 시작되지 않았으면 드래그 무시
        if (!_gameStarted) return;
        
        // 값 계산 먼저 (setState 없이)
        double newX = _controllerX + details.delta.dx;
        // 최대 드래그 거리 제한 (원의 경계 내에서만)
        if (newX > _maxDragDistance) {
          newX = _maxDragDistance;
        } else if (newX < -_maxDragDistance) {
          newX = -_maxDragDistance;
        }

        // 값이 실제로 변경되었을 때만 setState 호출
        if ((newX - _controllerX).abs() > 0.5) {
          setState(() {
            _controllerX = newX;
            _controllerY = 0.0;
          });
        } else {
          // setState 없이 값만 업데이트
          _controllerX = newX;
          _controllerY = 0.0;
        }

        // 목표 위치 업데이트
        _targetControllerX = _controllerX;

        // 걷기 상태 업데이트 (간단하게)
        // 컨트롤러가 움직이면 걷기 시작 (정지 중이 아니고 죽지 않았을 때만)
        if (_controllerX != 0 && !_isStunned && !_isDead) {
          bool newDirection = _controllerX > 0;
          if (!_isWalking) {
            _isWalking = true;
            _isWalkingRight = newDirection;
            _startCharacterUpdate();
          } else if (_isWalkingRight != newDirection) {
            _isWalkingRight = newDirection;
          }
        } else if (_controllerX == 0 && _isWalking && !_isStunned && !_isDead) {
          _isWalking = false;
          _stopCharacterUpdate();
        }
      },
      onPanEnd: (details) {
        setState(() {
          // 드래그 종료 시 원래 위치로 복귀
          _controllerX = 0.0;
          _controllerY = 0.0;
        });
        _targetControllerX = 0.0;
        // 걷기 애니메이션 정지
        if (_isWalking) {
          _isWalking = false;
          _stopCharacterUpdate();
        }
      },
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.3),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 배경 원
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            // 드래그 가능한 컨트롤러 원
            Transform.translate(
              offset: Offset(_controllerX, _controllerY),
              child: Container(
                width: _controllerRadius * 2,
                height: _controllerRadius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.8),
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 통합 캐릭터 업데이트 시작 (애니메이션 + 이동)
  void _startCharacterUpdate() {
    // 게임이 시작되지 않았거나 공격 중이거나 Stab 중이거나 대시 중이거나 정지 중이거나 죽음 상태면 걷기 시작하지 않음
    if (!_gameStarted || _isAttacking || _isStabbing || _isDashing || _isStunned || _isDead) return;

    _characterUpdateTimer?.cancel();

    // 걷기 애니메이션: 100ms마다 프레임 변경, 이동은 별도 처리
    _characterUpdateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      // 공격 중이거나 Stab 중이거나 대시 중이거나 정지 중이거나 죽음 상태거나 걷지 않으면 타이머 정지
      if (_isAttacking || _isStabbing || _isDashing || _isStunned || _isDead || !_isWalking || _targetControllerX == 0) {
        timer.cancel();
        return;
      }

      // 피격 중이면 걷기 애니메이션은 업데이트하지 않음 (피격 프레임 유지)
      if (_isAttacked) {
        return;
      }

      // 걷기 애니메이션 프레임 업데이트
      _walkFrameIndex = (_walkFrameIndex + 1) % 5; // 0-4 반복

      String newFrame;
      if (_isWalkingRight) {
        newFrame = 'assets/images/rpg/Ch_Walk_0${_walkFrameIndex + 1}.png';
      } else {
        newFrame = 'assets/images/rpg/Ch_Walk_Reverse_0${_walkFrameIndex + 1}.png';
      }

      if (mounted && newFrame != _currentWalkFrame) {
        setState(() {
          _currentWalkFrame = newFrame;
        });
      }
    });

    // 캐릭터 이동은 별도 타이머로 처리
    _characterMoveTimer?.cancel();
    _characterMoveTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      // 공격 중이거나 Stab 중이거나 대시 중이거나 정지 중이거나 죽음 상태거나 걷지 않으면 타이머 정지
      if (_isAttacking || _isStabbing || _isDashing || _isStunned || _isDead || !_isWalking || _targetControllerX == 0) {
        timer.cancel();
        return;
      }

      // 속도 감소 상태면 속도 절반으로
      double moveSpeed = _isSpeedReduced ? _characterMoveSpeed * 0.5 : _characterMoveSpeed;
      double newX = _characterX + (_targetControllerX > 0 ? moveSpeed : -moveSpeed);

      // 화면 경계 제한
      if (_screenWidth > 0) {
        double maxX = _screenWidth / 2 - 100;
        if (newX > maxX) newX = maxX;
        if (newX < -maxX) newX = -maxX;
      }

      if (mounted && (newX - _characterX).abs() > 0.1) {
        setState(() {
          _characterX = newX;
        });
      }
    });
  }

  // 통합 캐릭터 업데이트 정지
  void _stopCharacterUpdate() {
    _characterUpdateTimer?.cancel();
    _characterMoveTimer?.cancel();
    // 죽음 상태면 프레임 변경하지 않음
    if (_isDead) return;
    // 공격 중이 아니고 Stab 중이 아니고 대시 중이 아니고 피격 중이 아니면 기본 상태로 복귀
    if (!_isAttacking && !_isStabbing && !_isDashing && !_isAttacked) {
      setState(() {
        // 방향에 따라 다른 기본 이미지 사용
        if (_isWalkingRight) {
          _currentWalkFrame = 'assets/images/rpg/Ch_Basic.png';
        } else {
          _currentWalkFrame = 'assets/images/rpg/Ch_Basic_Reverse.png';
        }
        _walkFrameIndex = 0;
      });
    }
  }

  // 공격 애니메이션 시작
  void _startFightAnimation() {
    // 게임이 시작되지 않았거나 이미 공격 중이거나 Stab 중이거나 대시 중이거나 죽음 상태면 무시
    // 피격 중이어도 공격 가능
    if (!_gameStarted || _isAttacking || _isStabbing || _isDashing || _isDead) return;

    // 걷기 애니메이션과 이동 모두 중지
    _characterUpdateTimer?.cancel();
    _characterMoveTimer?.cancel();
    _isWalking = false;

    // 공격 상태 시작
    _isAttacking = true;
    _fightFrameIndex = 0;
    _lastAttackWasStab = false; // 일반 공격임을 표시

    // 일반 공격 효과음 재생
    SoundManager().playSwordSlice();

    // 첫 번째 프레임 표시
    if (mounted) {
      setState(() {
        if (_isWalkingRight) {
          _currentWalkFrame = 'assets/images/rpg/Ch_Fight_01.png';
        } else {
          _currentWalkFrame = 'assets/images/rpg/Ch_Fight_Reverse_01.png';
        }
      });
    }

    // 공격 애니메이션 타이머 시작 (각 프레임당 약 120ms - 더 부드럽게)
    _fightAnimationTimer?.cancel();
    _fightAnimationTimer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _fightFrameIndex++;

      // 공격 판정 프레임 체크 (3번째 프레임에서 판정)
      if (_fightFrameIndex == 2) {
        // 몬스터 피격 체크
        _checkMonsterHit();
      }

      if (_fightFrameIndex >= 5) {
        // 애니메이션 완료
        timer.cancel();
        _isAttacking = false;
        _fightFrameIndex = 0;

        // 기본 상태로 복귀 (죽음 상태가 아닐 때만)
        if (mounted && !_isDead) {
          setState(() {
            if (_isWalkingRight) {
              _currentWalkFrame = 'assets/images/rpg/Ch_Basic.png';
            } else {
              _currentWalkFrame = 'assets/images/rpg/Ch_Basic_Reverse.png';
            }
          });

          // 공격이 끝난 후 걷기 상태이면 바로 걷기 애니메이션 시작
          if (_isWalking && _targetControllerX != 0) {
            _startCharacterUpdate();
          }
        }
      } else {
        // 다음 프레임 표시
        if (mounted) {
          setState(() {
            if (_isWalkingRight) {
              _currentWalkFrame = 'assets/images/rpg/Ch_Fight_0${_fightFrameIndex + 1}.png';
            } else {
              _currentWalkFrame = 'assets/images/rpg/Ch_Fight_Reverse_0${_fightFrameIndex + 1}.png';
            }
          });
        }
      }
    });
  }

  // Stab 애니메이션 시작
  void _startStabAnimation() {
    // 게임이 시작되지 않았거나 이미 Stab 중이거나 쿨타임 중이거나 공격 중이거나 대시 중이거나 죽음 상태면 무시
    // 피격 중이어도 공격 가능
    if (!_gameStarted || _isStabbing || _stabOnCooldown || _isAttacking || _isDashing || _isDead) return;

    // 걷기 애니메이션과 이동 모두 중지
    _characterUpdateTimer?.cancel();
    _characterMoveTimer?.cancel();
    _isWalking = false;

    // Stab 상태 시작
    _isStabbing = true;
    _stabFrameIndex = 0;
    _lastAttackWasStab = true; // Stab 공격임을 표시

    // Stab 효과음 재생
    SoundManager().playSkill();

    // 쿨타임 시작 (7초)
    _stabOnCooldown = true;
    _stabCooldownRemaining = 7.0;
    _stabCooldownTimer?.cancel();
    _stabCooldownUpdateTimer?.cancel();

    // 쿨타임 타이머 시작
    _stabCooldownTimer = Timer(const Duration(milliseconds: 7000), () {
      if (mounted) {
        setState(() {
          _stabOnCooldown = false;
          _stabCooldownRemaining = 0.0;
        });
      }
      _stabCooldownUpdateTimer?.cancel();
    });

    // 쿨타임 업데이트 타이머 (0.1초마다)
    _stabCooldownUpdateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || !_stabOnCooldown) {
        timer.cancel();
        return;
      }

      _stabCooldownRemaining -= 0.1;
      if (_stabCooldownRemaining < 0) {
        _stabCooldownRemaining = 0.0;
      }

      if (mounted) {
        setState(() {});
      }
    });

    // 첫 번째 프레임 표시
    if (mounted) {
      setState(() {
        if (_isWalkingRight) {
          _currentWalkFrame = 'assets/images/rpg/Ch_Stab_1.png';
        } else {
          _currentWalkFrame = 'assets/images/rpg/Ch_Stab_Reverse_1.png';
        }
      });
    }

    // Stab 애니메이션 타이머 시작 (각 프레임당 약 180ms - 느리게)
    _stabAnimationTimer?.cancel();
    _stabAnimationTimer = Timer.periodic(const Duration(milliseconds: 135), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _stabFrameIndex++;

      // 공격 판정 프레임 체크 (2번째 프레임에서 판정)
      if (_stabFrameIndex == 1) {
        // 몬스터 피격 체크
        _checkMonsterHit();
      }

      if (_stabFrameIndex >= 4) {
        // 마지막 프레임(4번째)을 표시하고 추가 지연
        if (mounted) {
          setState(() {
            if (_isWalkingRight) {
              _currentWalkFrame = 'assets/images/rpg/Ch_Stab_4.png';
            } else {
              _currentWalkFrame = 'assets/images/rpg/Ch_Stab_Reverse_4.png';
            }
          });
        }

        // 마지막 프레임을 추가로 표시하기 위해 약간의 지연
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted) return;

          // 애니메이션 완료
          _stabAnimationTimer?.cancel();
          _isStabbing = false;
          _stabFrameIndex = 0;

          // 기본 상태로 복귀 (죽음 상태가 아닐 때만)
          if (mounted && !_isDead) {
            setState(() {
              if (_isWalkingRight) {
                _currentWalkFrame = 'assets/images/rpg/Ch_Basic.png';
              } else {
                _currentWalkFrame = 'assets/images/rpg/Ch_Basic_Reverse.png';
              }
            });

            // Stab이 끝난 후 걷기 상태이면 바로 걷기 애니메이션 시작
            if (_isWalking && _targetControllerX != 0) {
              _startCharacterUpdate();
            }
          }
        });

        // 타이머는 여기서 취소 (추가 지연은 Future.delayed로 처리)
        timer.cancel();
      } else {
        // 다음 프레임 표시
        if (mounted) {
          setState(() {
            if (_isWalkingRight) {
              _currentWalkFrame = 'assets/images/rpg/Ch_Stab_${_stabFrameIndex + 1}.png';
            } else {
              _currentWalkFrame = 'assets/images/rpg/Ch_Stab_Reverse_${_stabFrameIndex + 1}.png';
            }
          });
        }
      }
    });
  }

  // 대시 기능 시작
  void _startDash() {
    // 게임이 시작되지 않았거나 이미 대시 중이거나 공격/Stab 중이거나 쿨타임 중이거나 죽음 상태면 무시
    if (!_gameStarted || _isDashing || _isAttacking || _isStabbing || _dashOnCooldown || _isDead) return;

    // 걷기 애니메이션과 이동 타이머 중지
    _characterUpdateTimer?.cancel();
    _characterMoveTimer?.cancel();

    // 대시 상태 시작
    _isDashing = true;
    _dashDistance = 0.0;
    _walkFrameIndex = 0;

    // 대시 효과음 재생
    SoundManager().playDash();

    // 쿨타임 시작 (1.5초)
    _dashOnCooldown = true;
    _dashCooldownRemaining = 1.5;
    _dashCooldownTimer?.cancel();
    _dashCooldownUpdateTimer?.cancel();

    // 쿨타임 타이머 시작
    _dashCooldownTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _dashOnCooldown = false;
          _dashCooldownRemaining = 0.0;
        });
      }
      _dashCooldownUpdateTimer?.cancel();
    });

    // 쿨타임 업데이트 타이머 (0.1초마다)
    _dashCooldownUpdateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || !_dashOnCooldown) {
        timer.cancel();
        return;
      }

      _dashCooldownRemaining -= 0.1;
      if (_dashCooldownRemaining < 0) {
        _dashCooldownRemaining = 0.0;
      }

      if (mounted) {
        setState(() {});
      }
    });

    // 대시 방향 결정 (현재 걷는 방향 또는 기본 오른쪽)
    bool dashRight = _isWalkingRight;

    // 빠른 걷기 애니메이션 시작 (50ms마다 프레임 변경)
    _characterUpdateTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_isDashing || !mounted) {
        timer.cancel();
        return;
      }

      // 걷기 애니메이션 프레임 업데이트 (빠르게)
      _walkFrameIndex = (_walkFrameIndex + 1) % 5; // 0-4 반복

      String newFrame;
      if (dashRight) {
        newFrame = 'assets/images/rpg/Ch_Walk_0${_walkFrameIndex + 1}.png';
      } else {
        newFrame = 'assets/images/rpg/Ch_Walk_Reverse_0${_walkFrameIndex + 1}.png';
      }

      if (mounted && newFrame != _currentWalkFrame) {
        setState(() {
          _currentWalkFrame = newFrame;
        });
      }
    });

    // 빠른 이동 시작 (16ms마다, 빠른 속도로)
    _dashTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!_isDashing || !mounted) {
        timer.cancel();
        return;
      }

      // 빠른 이동 속도 (일반 걷기의 5배)
      double dashSpeed = 15.0;
      double moveDelta = dashRight ? dashSpeed : -dashSpeed;
      double newX = _characterX + moveDelta;

      // 대시 거리 누적
      _dashDistance += dashSpeed;

      // 화면 경계 제한
      if (_screenWidth > 0) {
        double maxX = _screenWidth / 2 - 100;
        if (newX > maxX) {
          newX = maxX;
          _dashDistance = _dashTotalDistance; // 경계에 도달하면 대시 종료
        }
        if (newX < -maxX) {
          newX = -maxX;
          _dashDistance = _dashTotalDistance; // 경계에 도달하면 대시 종료
        }
      }

      if (mounted) {
        setState(() {
          _characterX = newX;
        });
      }

      // 대시 거리 도달 시 대시 종료
      if (_dashDistance >= _dashTotalDistance) {
        timer.cancel();
        _characterUpdateTimer?.cancel();
        _isDashing = false;
        _dashDistance = 0.0;

        // 기본 상태로 복귀 (죽음 상태가 아닐 때만)
        if (mounted && !_isDead) {
          setState(() {
            if (dashRight) {
              _currentWalkFrame = 'assets/images/rpg/Ch_Basic.png';
            } else {
              _currentWalkFrame = 'assets/images/rpg/Ch_Basic_Reverse.png';
            }
            _walkFrameIndex = 0;
          });

          // 걷기 상태이면 걷기 애니메이션 시작
          if (_isWalking && _targetControllerX != 0) {
            _startCharacterUpdate();
          }
        }
      }
    });
  }

  // 몬스터 업데이트 시작
  void _startMonsterUpdate() {
    _monsterUpdateTimer?.cancel();
    _monsterFrameCounter = 0;

    // 몬스터 업데이트 타이머 (16ms마다 - 60fps)
    _monsterUpdateTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // 캐릭터가 죽었으면 몬스터 동작 중지
      if (_isDead) {
        timer.cancel();
        return;
      }

      // 캐릭터 방향으로 몬스터가 바라보도록 설정 (죽음 상태가 아닐 때만)
      if (!_monsterIsDead) {
        bool shouldFaceRight = _characterX > _monsterX;
        if (_monsterFacingRight != shouldFaceRight) {
          _monsterFacingRight = shouldFaceRight;
          if (mounted && !_monsterIsAttacking && !_monsterIsHurt) {
            setState(() {
              String idleFrame = _monsterFacingRight
                  ? 'assets/images/rpg/Boss_Idle_Reverse.png'
                  : 'assets/images/rpg/Boss_Idle.png';
              _monsterFrame = idleFrame;
            });
          }
        }
      }

      // 게임이 시작되었고 죽음 상태가 아니고 피격 중이 아니고 공격 중이 아니고 전조 모션 중이 아니고 휴식 중이 아니면 공격 시작 (제자리에서 공격)
      if (_gameStarted && !_monsterIsDead && !_monsterIsHurt && !_monsterIsAttacking && !_monsterIsPreparing && !_monsterIsResting) {
        _startMonsterAttack();
      }
    });
  }

  // 몬스터 공격 시작
  void _startMonsterAttack() {
    // 캐릭터가 죽었거나 몬스터가 죽었으면 공격하지 않음
    if (_isDead || _monsterIsDead) return;
    if (_monsterIsAttacking || _monsterIsPreparing) return;

    // 체력에 따른 공격 패턴 결정
    double healthPercent = (_monsterHealth / _monsterMaxHealth) * 100;

    // 30% 이하일 때 속도 증가
    if (healthPercent <= 30) {
      _monsterSpeedMultiplier = 1.5;
      _monsterAttackSpeedMultiplier = 1.5;
    } else {
      _monsterSpeedMultiplier = 1.0;
      _monsterAttackSpeedMultiplier = 1.0;
    }

    // 체력에 따른 공격 패턴 선택
    if (healthPercent > 60) {
      // 100~60%: 공격 1, 2를 랜덤하게 선택 (50:50 확률)
      final random = math.Random();
      _monsterAttackPattern = random.nextBool() ? 1 : 2;
      _isComboAttack = false;
    } else {
      // 60~0%: 다양한 패턴
      _selectLowHealthAttackPattern();
    }

    // 전조 모션 시작
    _startMonsterPreparing();
  }

  // 낮은 체력일 때 공격 패턴 선택
  void _selectLowHealthAttackPattern() {
    final random = math.Random();
    int patternType = random.nextInt(5); // 0~4

    switch (patternType) {
      case 0:
      // 공격1만
        _monsterAttackPattern = 1;
        _isComboAttack = false;
        break;
      case 1:
      // 공격3만
        _monsterAttackPattern = 3;
        _isComboAttack = false;
        break;
      case 2:
      // 연속 공격1 (2번 재생)
        _monsterAttackPattern = 1;
        _isComboAttack = true;
        _comboType = 1;
        _comboAttackCount = 2;
        break;
      case 3:
      case 4:
      // 2*3공격 (공격2, 공격3 연속)
        _monsterAttackPattern = 2;
        _isComboAttack = true;
        _comboType = 2;
        _comboAttackCount = 2;
        break;
    }
  }

  // 몬스터 전조 모션 시작
  void _startMonsterPreparing() {
    _monsterIsPreparing = true;
    _monsterPreparingFrameIndex = 0;
    _monsterPreparingTimer?.cancel();

    // 공격 패턴별 전조 모션 재생
    if (_monsterAttackPattern == 1) {
      // 공격 1: 2프레임 재생 후 0.6초 뒤 공격
      _playAttack1Preparing();
    } else if (_monsterAttackPattern == 2) {
      // 공격 2: 2프레임 재생 후 0.3초 뒤 점프 후 공격
      _playAttack2Preparing();
    } else if (_monsterAttackPattern == 3) {
      // 공격 3: 1프레임 재생 후 0.5초 뒤 공격
      _playAttack3Preparing();
    }
  }

  // 공격 1 전조 모션
  void _playAttack1Preparing() {
    // 연속 공격1인 경우 두 번째 공격은 전조 모션 없이 바로 시작
    if (_isComboAttack && _comboType == 1 && _comboAttackCount == 1) {
      // 두 번째 공격은 전조 모션 없이 바로 시작
      _monsterIsPreparing = false;
      _startActualAttack();
      return;
    }

    // 첫 번째 프레임
    String frame1 = _monsterFacingRight
        ? 'assets/images/rpg/Boss_Attack1_Reverse_1.png'
        : 'assets/images/rpg/Boss_Attack1_1.png';

    if (mounted) {
      setState(() {
        _monsterFrame = frame1;
      });
    }

    // 0.3초 후 두 번째 프레임 (속도 배율 적용)
    int frame1Duration = (300 / _monsterAttackSpeedMultiplier).round();
    Timer(Duration(milliseconds: frame1Duration), () {
      if (!mounted || !_monsterIsPreparing) return;

      String frame2 = _monsterFacingRight
          ? 'assets/images/rpg/Boss_Attack1_Reverse_2.png'
          : 'assets/images/rpg/Boss_Attack1_2.png';

      if (mounted) {
        setState(() {
          _monsterFrame = frame2;
        });
      }

      // 0.3초 후 공격 시작 (총 0.6초, 속도 배율 적용)
      int frame2Duration = (300 / _monsterAttackSpeedMultiplier).round();
      Timer(Duration(milliseconds: frame2Duration), () {
        if (!mounted || !_monsterIsPreparing) return;
        _monsterIsPreparing = false;
        _startActualAttack();
      });
    });
  }

  // 공격 2 전조 모션
  void _playAttack2Preparing() {
    // 첫 번째 프레임
    String frame1 = _monsterFacingRight
        ? 'assets/images/rpg/Boss_Attack2_Reverse_1.png'
        : 'assets/images/rpg/Boss_Attack2_1.png';

    if (mounted) {
      setState(() {
        _monsterFrame = frame1;
      });
    }

    // 0.15초 후 두 번째 프레임 (속도 배율 적용)
    int frame1Duration = (150 / _monsterAttackSpeedMultiplier).round();
    Timer(Duration(milliseconds: frame1Duration), () {
      if (!mounted || !_monsterIsPreparing) return;

      String frame2 = _monsterFacingRight
          ? 'assets/images/rpg/Boss_Attack2_3.png'
          : 'assets/images/rpg/Boss_Attack2_Reverse_3.png';

      if (mounted) {
        setState(() {
          _monsterFrame = frame2;
        });
      }

      // 0.15초 후 점프 후 공격 시작 (총 0.3초, 속도 배율 적용)
      // 연속 공격 2*3인 경우 점프 안함
      int frame2Duration = (150 / _monsterAttackSpeedMultiplier).round();
      Timer(Duration(milliseconds: frame2Duration), () {
        if (!mounted || !_monsterIsPreparing) return;
        _monsterIsPreparing = false;

        // 연속 공격 2*3인 경우 점프 없이 바로 공격
        if (_isComboAttack && _comboType == 2) {
          _startActualAttack();
        } else {
          _performAttack2Jump();
        }
      });
    });
  }

  // 공격 2 점프 후 공격
  void _performAttack2Jump() {
    // 원래 위치 저장
    _monsterOriginalX = _monsterX;

    // 점프 효과 (캐릭터 쪽으로 이동) - 캐릭터에 바짝 붙게 접근
    // 캐릭터 위치에서 약간의 여유만 두고 접근 (약 20픽셀 거리)
    double closeDistance = 20.0; // 캐릭터와의 최소 거리
    double jumpDirection = _characterX > _monsterX ? 1.0 : -1.0;
    double targetX = _characterX - (closeDistance * jumpDirection);

    // 화면 경계 제한
    if (_screenWidth > 0) {
      double maxX = _screenWidth / 2 - 100;
      if (targetX > maxX) targetX = maxX;
      if (targetX < -maxX) targetX = -maxX;
    }

    // 점프 애니메이션 (100ms)
    int frameCount = 0;
    double startX = _monsterX;

    Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      frameCount++;
      double progress = frameCount * 16 / 100.0;
      if (progress > 1.0) progress = 1.0;

      // 포물선 점프
      double easedProgress = 1.0 - math.pow(1.0 - progress, 2);
      double newX = startX + (targetX - startX) * easedProgress;
      double jumpHeight = 15.0 * math.sin(progress * math.pi); // 포물선

      if (mounted) {
        setState(() {
          _monsterX = newX;
          _monsterY = jumpHeight;
        });
      }

      if (progress >= 1.0) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _monsterY = 0.0;
          });
        }
        _startActualAttack();
      }
    });
  }

  // 공격 3 전조 모션
  void _playAttack3Preparing() {
    // Boss_Mouse 프레임
    String mouseFrame = _monsterFacingRight
        ? 'assets/images/rpg/Boss_Mouse_Reverse.png'
        : 'assets/images/rpg/Boss_Mouse.png';

    if (mounted) {
      setState(() {
        _monsterFrame = mouseFrame;
      });
    }

    // 0.5초 후 공격 시작 (속도 배율 적용)
    int prepareDuration = (500 / _monsterAttackSpeedMultiplier).round();
    Timer(Duration(milliseconds: prepareDuration), () {
      if (!mounted || !_monsterIsPreparing) return;
      _monsterIsPreparing = false;
      _startActualAttack();
    });
  }

  // 실제 공격 시작
  void _startActualAttack() {
    _monsterIsAttacking = true;
    _monsterAttackFrameIndex = 0;

    // 공격 패턴에 따른 효과음 재생
    if (_monsterAttackPattern == 1) {
      SoundManager().playAttack1();
    } else if (_monsterAttackPattern == 2) {
      SoundManager().playAttack2();
    } else if (_monsterAttackPattern == 3) {
      SoundManager().playAttack3();
    }

    // 첫 번째 프레임 표시
    String firstFrame = _getAttackFrame(_monsterAttackPattern, 1);
    if (mounted) {
      setState(() {
        _monsterFrame = firstFrame;
        _monsterY = 0.0; // 공격 중에는 점프 없음
      });
    }

    // 공격 애니메이션 타이머 시작
    _monsterAttackTimer?.cancel();
    int maxFrames = _monsterAttackPattern == 3 ? 6 : 4; // 공격 3은 6프레임, 나머지는 4프레임
    // 공격2는 더 느리게 (200ms), 나머지는 180ms (속도 배율 적용)
    int baseFrameDuration = _monsterAttackPattern == 2 ? 200 : 180;
    int frameDuration = (baseFrameDuration / _monsterAttackSpeedMultiplier).round();

    _monsterAttackTimer = Timer.periodic(Duration(milliseconds: frameDuration), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _monsterAttackFrameIndex++;

      // 공격 판정 프레임 체크 (공격 패턴에 따라 다름)
      int hitFrame = _monsterAttackPattern == 3 ? 3 : 2; // 공격3은 3번째, 나머지는 2번째 프레임에서 판정
      if (_monsterAttackFrameIndex == hitFrame) {
        // 캐릭터 피격 체크
        _checkCharacterHit();
      }

      if (_monsterAttackFrameIndex >= maxFrames) {
        // 공격 완료
        timer.cancel();
        _monsterIsAttacking = false;
        _monsterAttackFrameIndex = 0;

        // 연속 공격 처리
        if (_isComboAttack && _comboAttackCount > 0) {
          _comboAttackCount--;

          if (_comboType == 1) {
            // 연속 공격1: 다시 공격1 실행 (전조 모션 없이)
            _monsterIsPreparing = false;
            _startActualAttack();
          } else if (_comboType == 2) {
            // 연속 공격 2*3: 공격2 후 공격3으로 전환
            if (_monsterAttackPattern == 2) {
              _monsterAttackPattern = 3;
              _monsterIsPreparing = false;
              _startActualAttack();
            } else {
              // 공격3 완료, 연속 공격 종료
              _isComboAttack = false;
              _comboAttackCount = 0;
              _finishAttack();
            }
          }
        } else {
          // 일반 공격 완료 또는 연속 공격 종료
          _isComboAttack = false;
          _comboAttackCount = 0;

          // 공격2인 경우 원래 위치로 복귀 (연속 공격이 아닐 때만)
          if (_monsterAttackPattern == 2 && (_monsterX - _monsterOriginalX).abs() > 1.0 && !_isComboAttack) {
            _returnMonsterToOriginalPosition();
          } else {
            _finishAttack();
          }
        }
      } else {
        // 다음 프레임 표시
        if (mounted) {
          setState(() {
            _monsterFrame = _getAttackFrame(_monsterAttackPattern, _monsterAttackFrameIndex + 1);
          });
        }
      }
    });
  }

  // 공격 프레임 경로 가져오기
  String _getAttackFrame(int pattern, int frameNumber) {
    if (_monsterFacingRight) {
      // 오른쪽을 보고 있는 경우
      return 'assets/images/rpg/Boss_Attack${pattern}_Reverse_$frameNumber.png';
    } else {
      // 왼쪽을 보고 있는 경우
      return 'assets/images/rpg/Boss_Attack${pattern}_$frameNumber.png';
    }
  }

  // 공격 패턴별 공격 범위 가져오기
  double _getAttackRange(int pattern) {
    switch (pattern) {
      case 1:
        return 120.0; // 공격1: 보통 범위
      case 2:
        return 100.0; // 공격2: 근거리 (붙어서 공격)
      case 3:
        return 180.0; // 공격3: 원거리 (공격범위 넓음)
      default:
        return 120.0;
    }
  }

  // 공격 완료 처리
  void _finishAttack() {
    // 공격 패턴 순환은 _startMonsterAttack()에서 처리하므로 여기서는 하지 않음

    // 죽음 상태가 아니면 대기 상태로 복귀
    if (!_monsterIsDead && mounted) {
      setState(() {
        String idleFrame = _monsterFacingRight
            ? 'assets/images/rpg/Boss_Idle_Reverse.png'
            : 'assets/images/rpg/Boss_Idle.png';
        _monsterFrame = idleFrame;
      });
    }

    // 공격 패턴 사이에 휴식 추가 (죽음 상태가 아닐 때만)
    if (!_monsterIsDead) {
      _startMonsterRest();
    }
  }

  // 몬스터 휴식 시작
  void _startMonsterRest() {
    _monsterIsResting = true;
    _monsterRestTimer?.cancel();

    // 3.5초 휴식 (속도 배율 적용 - 빠를수록 휴식도 짧게)
    int restDuration = (3500 / _monsterSpeedMultiplier).round();
    _monsterRestTimer = Timer(Duration(milliseconds: restDuration), () {
      if (mounted) {
        setState(() {
          _monsterIsResting = false;
        });
      }
    });
  }

  // 몬스터 원래 위치로 복귀 (공격2 후)
  void _returnMonsterToOriginalPosition() {
    double startX = _monsterX;
    double targetX = _monsterOriginalX;
    int frameCount = 0;
    const int totalFrames = 20; // 약 320ms (16ms * 20)

    Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      frameCount++;
      double progress = frameCount / totalFrames;
      if (progress > 1.0) progress = 1.0;

      // 이징 함수 (ease-out)
      double easedProgress = 1.0 - math.pow(1.0 - progress, 2);

      double newX = startX + (targetX - startX) * easedProgress;

      if (mounted) {
        setState(() {
          _monsterX = newX;
        });
      }

      if (progress >= 1.0) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _monsterX = targetX;
          });
        }

        // 공격 완료 처리
        _finishAttack();
      }
    });
  }

  // 캐릭터 피격 체크
  void _checkCharacterHit() {
    // 이미 피격 중이면 무시
    if (_isAttacked) return;

    // 공격 패턴별 공격 범위 설정
    double attackRange = _getAttackRange(_monsterAttackPattern);

    // 캐릭터와 몬스터 사이의 거리 계산
    double distance = (_characterX - _monsterX).abs();

    // 공격 범위 내에 있으면 피격
    if (distance <= attackRange) {
      // 데미지 계산 (몬스터 공격력 - 사용자 방어력, 최소 1)
      int damage = (_monsterAttack - _playerDefense) > 0
          ? (_monsterAttack - _playerDefense)
          : 1;

      if (mounted) {
        setState(() {
          _playerHealth -= damage;

          // 체력이 0 이하가 되면 0으로 고정
          if (_playerHealth <= 0) {
            _playerHealth = 0;
            // 캐릭터 사망 로직
            if (!_isDead) {
              _isDead = true;
              _startDeathAnimation();
              print('캐릭터 사망!');
            }
          }
        });
      }

      print('캐릭터 피격! (공격 패턴: $_monsterAttackPattern) 데미지: $damage, 남은 체력: $_playerHealth/$_playerMaxHealth');

      _startAttackedAnimation(_monsterAttackPattern);
    }
  }

  // 피격 애니메이션 시작
  void _startAttackedAnimation(int attackPattern) {
    if (_isAttacked) return;

    // 걷기 상태 저장 (피격 후 복원용)
    bool wasWalking = _isWalking;
    double savedTargetControllerX = _targetControllerX;

    // 공격/Stab/대시 애니메이션만 중지 (걷기는 피격 중에도 가능)
    _fightAnimationTimer?.cancel();
    _stabAnimationTimer?.cancel();
    _dashTimer?.cancel();
    
    // 공격/Stab/대시 상태 해제 (피격 중에도 버튼 클릭 가능하도록)
    _isAttacking = false;
    _isStabbing = false;
    _isDashing = false;

    _isAttacked = true;

    // 공격 패턴별 효과 적용
    if (attackPattern == 1) {
      // 공격 1: 일반 피격 프레임 (속도 감소 없음)
      String attackedFrame = _isWalkingRight
          ? 'assets/images/rpg/Ch_Attacked.png'
          : 'assets/images/rpg/Ch_Attacked_Reverse.png';
      if (mounted) {
        setState(() {
          _currentWalkFrame = attackedFrame;
        });
      }
      // 피격 애니메이션 지속 시간 (500ms)
      _attackedAnimationTimer = Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _isAttacked = false;
        _returnToNormalState(wasWalking, savedTargetControllerX);
      });
    } else if (attackPattern == 2) {
      // 공격 2: 정지 (2초간) + Poison 프레임
      _applyStun();
      String attackedFrame = _isWalkingRight
          ? 'assets/images/rpg/Ch_Attacked_Poison_Reverse.png'
          : 'assets/images/rpg/Ch_Attacked_Poison.png';
      if (mounted) {
        setState(() {
          _currentWalkFrame = attackedFrame;
        });
      }
      // 정지 상태는 2초간 유지
      _attackedAnimationTimer = Timer(const Duration(milliseconds: 2000), () {
        if (!mounted) return;
        _isAttacked = false;
        _isStunned = false;
        _returnToNormalState(wasWalking, savedTargetControllerX);
      });
    } else if (attackPattern == 3) {
      // 공격 3: 뒤로 튕겨짐
      _applyKnockback();
      // 일반 피격 프레임
      String attackedFrame = _isWalkingRight
          ? 'assets/images/rpg/Ch_Attacked.png'
          : 'assets/images/rpg/Ch_Attacked_Reverse.png';
      if (mounted) {
        setState(() {
          _currentWalkFrame = attackedFrame;
        });
      }
      // 피격 애니메이션 지속 시간 (500ms)
      _attackedAnimationTimer = Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _isAttacked = false;
        _returnToNormalState(wasWalking, savedTargetControllerX);
      });
    }
  }

  // 기본 상태로 복귀
  void _returnToNormalState(bool wasWalking, double savedTargetControllerX) {
    // 죽음 상태면 프레임 변경하지 않음
    if (_isDead) return;
    if (mounted) {
      setState(() {
        if (_isWalkingRight) {
          _currentWalkFrame = 'assets/images/rpg/Ch_Basic.png';
        } else {
          _currentWalkFrame = 'assets/images/rpg/Ch_Basic_Reverse.png';
        }
      });

      // 피격 전 걷기 상태였거나, 현재 드래그 컨트롤러가 움직이고 있으면 걷기 재시작
      // 현재 컨트롤러 상태를 우선 확인 (사용자가 계속 드래그하고 있을 수 있음)
      if (!_isStunned) {
        if (_controllerX != 0 || savedTargetControllerX != 0) {
          // 현재 컨트롤러 위치가 있으면 그것을 사용, 없으면 저장된 값 사용
          double controllerX = _controllerX != 0 ? _controllerX : savedTargetControllerX;
          if (controllerX != 0) {
            _isWalking = true;
            _targetControllerX = controllerX;
            _isWalkingRight = controllerX > 0;
            _startCharacterUpdate();
          }
        }
      }
    }
  }

  // 속도 감소 효과 (공격 1)
  void _applySpeedReduction() {
    _isSpeedReduced = true;
    _speedReducedTimer?.cancel();
    _speedReducedTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _isSpeedReduced = false;
        });
      }
    });
  }

  // 정지 효과 (공격 2)
  void _applyStun() {
    _isStunned = true;
    _stunnedTimer?.cancel();
    // 정지 상태는 _attackedAnimationTimer에서 해제됨
  }

  // 튕겨짐 효과 (공격 3)
  void _applyKnockback() {
    // 튕겨지는 방향 결정 (몬스터 반대 방향)
    double knockbackDirection = _characterX > _monsterX ? 1.0 : -1.0;
    double knockbackDistance = 50.0; // 튕겨지는 거리
    double startX = _characterX;

    _characterKnockbackTimer?.cancel();

    // 튕겨지는 애니메이션 (200ms)
    _characterKnockbackTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      double progress = timer.tick * 16 / 200.0; // 0.0 ~ 1.0
      if (progress > 1.0) progress = 1.0;

      // 이징 함수 (ease-out)
      double easedProgress = 1.0 - math.pow(1.0 - progress, 3);

      double currentKnockback = knockbackDistance * easedProgress * knockbackDirection;
      double newCharacterX = startX + currentKnockback;

      // 화면 경계 제한
      if (_screenWidth > 0) {
        double maxX = _screenWidth / 2 - 100;
        if (newCharacterX > maxX) newCharacterX = maxX;
        if (newCharacterX < -maxX) newCharacterX = -maxX;
      }

      if (mounted) {
        setState(() {
          _characterX = newCharacterX;
          _characterKnockbackX = currentKnockback;
        });
      }

      if (progress >= 1.0) {
        timer.cancel();
        // 튕겨짐 완료, 복귀하지 않음
        if (mounted) {
          setState(() {
            _characterKnockbackX = 0.0; // 오프셋 초기화
          });
        }
      }
    });
  }

  // 죽음 애니메이션 시작
  void _startDeathAnimation() {
    // 이미 죽음 애니메이션이 진행 중이면 무시
    if (_deathAnimationTimer != null) return;

    // 죽음 효과음 재생
    SoundManager().playDie();

    // 모든 다른 애니메이션과 이동 중지
    _characterUpdateTimer?.cancel();
    _characterMoveTimer?.cancel();
    _fightAnimationTimer?.cancel();
    _stabAnimationTimer?.cancel();
    _dashTimer?.cancel();
    _attackedAnimationTimer?.cancel();
    _isWalking = false;
    _isAttacking = false;
    _isStabbing = false;
    _isDashing = false;
    _isAttacked = false;

    // 몬스터 동작 중지
    _monsterUpdateTimer?.cancel();
    _monsterAttackTimer?.cancel();
    _monsterPreparingTimer?.cancel();
    _monsterRestTimer?.cancel();

    // 죽음 애니메이션 프레임 인덱스 초기화
    _deathFrameIndex = 0;

    // 첫 번째 프레임 표시
    if (mounted) {
      setState(() {
        if (_isWalkingRight) {
          _currentWalkFrame = 'assets/images/rpg/Ch_Died_01.png';
        } else {
          _currentWalkFrame = 'assets/images/rpg/Ch_Died_Reverse_01.png';
        }
      });
    }

    // 죽음 애니메이션 타이머 시작 (각 프레임당 약 200ms)
    _deathAnimationTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _deathFrameIndex++;

      if (_deathFrameIndex >= 4) {
        // 마지막 프레임(4번째)을 표시하고 애니메이션 완료
        if (mounted) {
          setState(() {
            if (_isWalkingRight) {
              _currentWalkFrame = 'assets/images/rpg/Ch_Died_04.png';
            } else {
              _currentWalkFrame = 'assets/images/rpg/Ch_Died_Reverse_04.png';
            }
          });
        }
        timer.cancel();
        _deathAnimationTimer = null;
        // 캐릭터 사망 애니메이션 완료 후 실패 다이얼로그 표시
        _displayFailureDialog();
      } else {
        // 다음 프레임 표시
        if (mounted) {
          setState(() {
            if (_isWalkingRight) {
              _currentWalkFrame = 'assets/images/rpg/Ch_Died_0${_deathFrameIndex + 1}.png';
            } else {
              _currentWalkFrame = 'assets/images/rpg/Ch_Died_Reverse_0${_deathFrameIndex + 1}.png';
            }
          });
        }
      }
    });
  }

  // 튕겨짐에서 원래 위치로 복귀
  void _returnCharacterFromKnockback(double targetX) {
    double startX = _characterX;
    int frameCount = 0;
    const int totalFrames = 15; // 약 240ms (16ms * 15)

    Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      frameCount++;
      double progress = frameCount / totalFrames;
      if (progress > 1.0) progress = 1.0;

      // 이징 함수 (ease-out)
      double easedProgress = 1.0 - math.pow(1.0 - progress, 2);

      double newX = startX + (targetX - startX) * easedProgress;

      if (mounted) {
        setState(() {
          _characterX = newX;
          _characterKnockbackX = newX - targetX;
        });
      }

      if (progress >= 1.0) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _characterX = targetX;
            _characterKnockbackX = 0.0;
          });
        }
      }
    });
  }

  // 몬스터 피격 체크
  void _checkMonsterHit() {
    // 이미 피격 중이면 무시
    if (_monsterIsHurt) return;

    // 캐릭터와 몬스터 사이의 거리 계산
    double distance = (_characterX - _monsterX).abs();

    // 공격 타입에 따라 공격 범위 설정 (Stab 공격은 더 큰 범위)
    double attackRange = _lastAttackWasStab ? 180.0 : _attackRange; // Stab: 180.0, 일반: 120.0

    // 공격 범위 내에 있으면 몬스터 피격
    if (distance <= attackRange) {
      // 데미지 계산 (공격 타입에 따라 구분)
      // Stab 공격: 25, 일반 공격: 10
      int damage = _lastAttackWasStab ? 25 : _playerAttack;

      if (mounted) {
        setState(() {
          _monsterHealth -= damage;

          // 체력이 0 이하가 되면 0으로 고정
          if (_monsterHealth <= 0) {
            _monsterHealth = 0;
            // 몬스터 사망 로직
            if (!_monsterIsDead) {
              _monsterIsDead = true;
              _startMonsterDeathAnimation();
              print('몬스터 처치!');
            }
          }
        });
      }

      String attackType = _lastAttackWasStab ? 'Stab' : '일반공격';
      print('몬스터 피격! ($attackType) 데미지: $damage, 남은 체력: $_monsterHealth/$_monsterMaxHealth');

      _startMonsterHurtAnimation(_lastAttackWasStab);
    }
  }

  // 몬스터 피격 애니메이션 시작
  void _startMonsterHurtAnimation(bool isStabAttack) {
    if (_monsterIsHurt) return;

    // 몬스터 공격 및 이동 중지
    _monsterAttackTimer?.cancel();
    _monsterPreparingTimer?.cancel();
    _monsterUpdateTimer?.cancel();
    _monsterKnockbackTimer?.cancel();

    _monsterIsHurt = true;
    _monsterIsAttacking = false;
    _monsterIsPreparing = false;

    // 공격 타입에 따라 밀려나는 거리 설정
    double knockbackDistance = isStabAttack ? 40.0 : 15.0; // Stab: 더 많이, 일반: 적게
    double knockbackDirection = _monsterFacingRight ? -1.0 : 1.0; // 몬스터가 보는 방향의 반대로

    // 파티클 이펙트 생성 (Stab 공격일 때만)
    if (isStabAttack) {
      _createHitParticles(isStabAttack);
    }

    // 피격 프레임 설정 (방향에 따라)
    String hurtFrame = _monsterFacingRight
        ? 'assets/images/rpg/Boss_Hurt_Reverse.png'
        : 'assets/images/rpg/Boss_Hurt.png';

    if (mounted) {
      setState(() {
        _monsterFrame = hurtFrame;
        _monsterY = 0.0; // 피격 중에는 점프 없음
        _monsterKnockbackX = 0.0;
      });
    }

    // 밀려나는 애니메이션 (200ms)
    double currentKnockback = 0.0;
    _monsterKnockbackTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted || !_monsterIsHurt) {
        timer.cancel();
        return;
      }

      double progress = timer.tick * 16 / 200.0; // 0.0 ~ 1.0
      if (progress > 1.0) progress = 1.0;

      // 이징 함수 (ease-out)
      double easedProgress = 1.0 - math.pow(1.0 - progress, 3);

      currentKnockback = knockbackDistance * easedProgress * knockbackDirection;

      if (mounted) {
        setState(() {
          _monsterKnockbackX = currentKnockback;
        });
      }

      if (progress >= 1.0) {
        timer.cancel();
        // 원래 위치로 복귀 (부드럽게)
        _returnToOriginalPosition();
      }
    });

    // 피격 애니메이션 지속 시간 (500ms)
    _monsterHurtTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      _monsterIsHurt = false;

      // 죽음 상태가 아니면 대기 상태로 복귀
      if (!_monsterIsDead && mounted) {
        setState(() {
          String idleFrame = _monsterFacingRight
              ? 'assets/images/rpg/Boss_Idle_Reverse.png'
              : 'assets/images/rpg/Boss_Idle.png';
          _monsterFrame = idleFrame;
          _monsterKnockbackX = 0.0;
        });

        // 몬스터 업데이트 재시작 (비활성화 - 몬스터 가만히 있음)
        _startMonsterUpdate();
      }
    });
  }

  // 몬스터 죽음 애니메이션 시작
  void _startMonsterDeathAnimation() {
    // 이미 죽음 애니메이션이 진행 중이면 무시
    if (_monsterDeathAnimationTimer != null) return;

    // 죽음 효과음 재생
    SoundManager().playDie();

    // 모든 몬스터 동작 중지
    _monsterUpdateTimer?.cancel();
    _monsterAttackTimer?.cancel();
    _monsterPreparingTimer?.cancel();
    _monsterHurtTimer?.cancel();
    _monsterKnockbackTimer?.cancel();
    _monsterRestTimer?.cancel();
    _monsterIsAttacking = false;
    _monsterIsPreparing = false;
    _monsterIsHurt = false;

    // 캐릭터를 기본 상태로 설정 (동작은 중지하지 않음)
    if (mounted) {
      setState(() {
        if (_isWalkingRight) {
          _currentWalkFrame = 'assets/images/rpg/Ch_Basic.png';
        } else {
          _currentWalkFrame = 'assets/images/rpg/Ch_Basic_Reverse.png';
        }
      });
    }

    // 죽음 애니메이션 프레임 인덱스 초기화
    _monsterDeathFrameIndex = 0;

    // 첫 번째 프레임 표시
    if (mounted) {
      setState(() {
        if (_monsterFacingRight) {
          _monsterFrame = 'assets/images/rpg/Boss_Death_Reverse_1.png';
        } else {
          _monsterFrame = 'assets/images/rpg/Boss_Death_1.png';
        }
        _monsterY = 0.0; // 첫 번째 프레임은 원래 위치
      });
    }

    // 죽음 애니메이션 타이머 시작 (각 프레임당 약 200ms)
    _monsterDeathAnimationTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _monsterDeathFrameIndex++;

      if (_monsterDeathFrameIndex >= 4) {
        // 마지막 프레임(4번째)을 표시하고 애니메이션 완료
        if (mounted) {
          setState(() {
            if (_monsterFacingRight) {
              _monsterFrame = 'assets/images/rpg/Boss_Death_Reverse_4.png';
            } else {
              _monsterFrame = 'assets/images/rpg/Boss_Death_4.png';
            }
            // 2,3,4 프레임은 아래로 이동 (Y 오프셋 추가)
            _monsterY = -40.0; // 아래로 40픽셀 이동
          });
        }
        timer.cancel();
        _monsterDeathAnimationTimer = null;
        // 몬스터 사망 애니메이션 완료 후 보상 다이얼로그 표시
        _displayRewardDialog();
      } else {
        // 다음 프레임 표시
        if (mounted) {
          setState(() {
            if (_monsterFacingRight) {
              _monsterFrame = 'assets/images/rpg/Boss_Death_Reverse_${_monsterDeathFrameIndex + 1}.png';
            } else {
              _monsterFrame = 'assets/images/rpg/Boss_Death_${_monsterDeathFrameIndex + 1}.png';
            }
            // 2,3,4 프레임은 아래로 이동 (Y 오프셋 추가)
            if (_monsterDeathFrameIndex >= 1) { // 2번째 프레임부터 (인덱스 1부터)
              _monsterY = -40.0; // 아래로 40픽셀 이동
            }
          });
        }
      }
    });
  }

  // 원래 위치로 복귀
  void _returnToOriginalPosition() {
    double startKnockback = _monsterKnockbackX;
    int frameCount = 0;
    const int totalFrames = 10; // 약 160ms (16ms * 10)

    Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted || !_monsterIsHurt) {
        timer.cancel();
        return;
      }

      frameCount++;
      double progress = frameCount / totalFrames;
      if (progress > 1.0) progress = 1.0;

      // 이징 함수 (ease-out)
      double easedProgress = 1.0 - math.pow(1.0 - progress, 2);

      if (mounted) {
        setState(() {
          _monsterKnockbackX = startKnockback * (1.0 - easedProgress);
        });
      }

      if (progress >= 1.0) {
        timer.cancel();
      }
    });
  }

  // 피격 파티클 생성
  void _createHitParticles(bool isStabAttack) {
    _hitParticles.clear();
    final random = math.Random();
    int particleCount = isStabAttack ? 30 : 15; // Stab: 더 많은 파티클

    // 몬스터 위치 계산 (화면 좌표)
    double monsterScreenX = _screenWidth / 2 + _monsterX;
    double monsterScreenY = _screenHeight - 40 - _getMonsterBottomOffset();

    for (int i = 0; i < particleCount; i++) {
      double angle = random.nextDouble() * 2 * math.pi;
      double speed = isStabAttack
          ? 100 + random.nextDouble() * 150
          : 50 + random.nextDouble() * 100;

      // 색상 (주황색, 빨간색, 노란색)
      List<Color> colors = [
        Colors.orange,
        Colors.red,
        Colors.deepOrange,
        Colors.orangeAccent,
        Colors.redAccent,
      ];
      Color particleColor = colors[random.nextInt(colors.length)];

      _hitParticles.add(Particle(
        x: monsterScreenX + (random.nextDouble() - 0.5) * 50,
        y: monsterScreenY + (random.nextDouble() - 0.5) * 50,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - 50, // 위로 튀어오르는 효과
        color: particleColor,
        size: isStabAttack
            ? 3 + random.nextDouble() * 5
            : 2 + random.nextDouble() * 4,
        life: 0.3 + random.nextDouble() * 0.4,
        maxLife: 0.3 + random.nextDouble() * 0.4,
      ));
    }

    // 파티클 업데이트 타이머 시작
    _particleUpdateTimer?.cancel();
    _particleUpdateTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      bool hasAliveParticles = false;
      for (var particle in _hitParticles) {
        if (particle.isAlive()) {
          particle.update(16 / 1000.0); // dt in seconds
          hasAliveParticles = true;
        }
      }

      if (hasAliveParticles) {
        setState(() {}); // 파티클 업데이트를 위해 리빌드
      } else {
        timer.cancel();
      }
    });
  }

  // 점프 오프셋 계산 (포물선)
  double _calculateJumpOffset(int frameIndex) {
    // 프레임 3, 4, 5 (인덱스 2, 3, 4)에서 점프 효과
    if (frameIndex >= 2 && frameIndex <= 4) {
      // 포물선 공식: y = -a * (x - center)^2 + maxHeight
      // frameIndex 2, 3, 4를 -1, 0, 1로 변환 (중앙이 3)
      double normalizedX = (frameIndex - 3).toDouble();
      // 프레임 카운터를 이용한 부드러운 보간 (0~9 사이)
      double frameProgress = _monsterFrameCounter / 9.0;
      // 다음 프레임까지의 진행도 반영
      double nextNormalizedX = ((frameIndex + 1) % 6 - 3).toDouble();
      if (frameIndex == 4) nextNormalizedX = -1.0; // 5 다음은 0으로 돌아가므로

      // 현재 프레임과 다음 프레임 사이 보간
      double interpolatedX = normalizedX + (nextNormalizedX - normalizedX) * frameProgress;

      // 포물선: 최대 높이 5픽셀, 중심이 프레임 3
      double maxHeight = 5.0;
      double jumpHeight = -maxHeight * (interpolatedX * interpolatedX) + maxHeight;
      return jumpHeight;
    }
    return 0.0;
  }

  // 몬스터 크기 가져오기
  double _getMonsterWidth() {
    // 피격 프레임
    if (_monsterFrame.contains('Boss_Hurt') || _monsterFrame.contains('Boss_Hurt_Reverse')) {
      return 205.0;
    }
    // 공격3의 5번째 프레임
    if (_monsterFrame.contains('Boss_Attack3_5') || _monsterFrame.contains('Boss_Attack3_Reverse_5')) {
      return 230.0;
    }
    // 공격3의 4번째 프레임
    if (_monsterFrame.contains('Boss_Attack3_4') || _monsterFrame.contains('Boss_Attack3_Reverse_4')) {
      return 190.0;
    }
    // 공격1의 3번째 프레임
    if (_monsterFrame.contains('Boss_Attack1_3') || _monsterFrame.contains('Boss_Attack1_Reverse_3')) {
      return 250.0;
    }
    // 공격1의 4번째 프레임
    if (_monsterFrame.contains('Boss_Attack1_4') || _monsterFrame.contains('Boss_Attack1_Reverse_4')) {
      return 180.0;
    }
    // 기본 크기
    return 165.0;
  }

  // 몬스터 bottom 오프셋 계산 (크기가 커졌을 때 위치 보정)
  double _getMonsterBottomOffset() {
    double currentWidth = _getMonsterWidth();
    double baseWidth = 165.0;
    // 크기 차이의 절반만큼 bottom을 낮춰서 발 위치를 맞춤
    return (currentWidth - baseWidth) / 2;
  }

  // 몬스터 위젯
  Widget _buildMonster() {
    final imageProvider = _imageCache[_monsterFrame] ??
        AssetImage(_monsterFrame);

    double monsterSize = _getMonsterWidth();

    return Image(
      image: imageProvider,
      width: monsterSize,
      height: monsterSize,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: monsterSize,
          height: monsterSize,
          color: Colors.red.withOpacity(0.3),
          child: const Center(
            child: Icon(Icons.bug_report, size: 80, color: Colors.red),
          ),
        );
      },
    );
  }

  // 캐릭터 위젯
  Widget _buildCharacter() {
    // 이미지 캐시에서 가져오거나 새로 생성
    final imageProvider = _imageCache[_currentWalkFrame] ??
        AssetImage(_currentWalkFrame);

    // Stab 애니메이션일 때는 더 큰 크기 사용
    final bool isStabFrame = _currentWalkFrame.contains('Ch_Stab');
    final double imageSize = isStabFrame ? 220.0 : 165.0;

    return Image(
      image: imageProvider,
      width: imageSize,
      height: imageSize,
      fit: BoxFit.contain,
      gaplessPlayback: true, // 이미지 전환 시 깜빡임 방지 - 이전 이미지를 유지
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        // 이미지가 완전히 로드되면 표시
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        // 로딩 중일 때는 이전 프레임을 유지 (gaplessPlayback과 함께 작동)
        // 빈 공간이 생기지 않도록 처리
        return child;
      },
      loadingBuilder: (context, child, loadingProgress) {
        // 로딩 중에도 이전 이미지가 보이도록 (gaplessPlayback 덕분에)
        if (loadingProgress == null) {
          return child;
        }
        // 로딩 중일 때도 이미지 표시 (이전 프레임 유지)
        return child;
      },
      errorBuilder: (context, error, stackTrace) {
        // 이미지 로드 실패 시 기본 이미지 표시
        final bool isStabFrame = _currentWalkFrame.contains('Ch_Stab');
        final double imageSize = isStabFrame ? 220.0 : 165.0;
        return Container(
          width: imageSize,
          height: imageSize,
          color: Colors.grey.withOpacity(0.3),
          child: const Center(
            child: Icon(Icons.person, size: 80, color: Colors.grey),
          ),
        );
      },
    );
  }

  // HP 칸 수 계산 (0~10)
  int _calculateHpBars(int currentHp, int maxHp) {
    if (maxHp <= 0) return 0;
    double ratio = currentHp / maxHp;
    int bars = (ratio * 10).round();
    return bars.clamp(0, 10);
  }

  // HP바 위젯
  Widget _buildHpBar(int currentHp, int maxHp) {
    int hpBars = _calculateHpBars(currentHp, maxHp);

    // HP바 이미지 경로 결정
    String hpBarImage;
    if (hpBars == 0) {
      hpBarImage = 'assets/images/Icon_HpXp_EmptyBar.png';
    } else {
      hpBarImage = 'assets/images/Icon_HpBar_$hpBars.png';
    }

    return Image.asset(
      hpBarImage,
      width: 200,
      height: 30,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // 이미지가 없을 경우 빈칸 표시
        return Image.asset(
          'assets/images/Icon_HpXp_EmptyBar.png',
          width: 200,
          height: 30,
          fit: BoxFit.contain,
        );
      },
    );
  }

  // 실패 다이얼로그 표시
  void _displayFailureDialog() {
    // 게임 오버 효과음 재생
    SoundManager().playGameOver();
    
    setState(() {
      _showFailureDialog = true;
    });
  }

  // 실패 다이얼로그 위젯
  Widget _buildFailureDialog() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: Container(
            width: 550,
            height: 300,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/map_row.png'),
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        '처치 실패',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 6,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '-HP 50',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 4,
                              offset: Offset(1, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // 왼쪽 아래: 홈으로 버튼
                Positioned(
                  bottom: 20,
                  left: 70,
                  child: GestureDetector(
                    onTap: () {
                      SoundManager().playClick();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const HomeScreen()),
                      );
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          'assets/images/MainButton.png',
                          width: 110,
                          height: 60,
                          fit: BoxFit.contain,
                        ),
                        const Text(
                          '홈으로',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 보상 다이얼로그 표시
  void _displayRewardDialog() {
    setState(() {
      _showRewardDialog = true;
      _isChestClosed = true;
      _rewardPetAsset = null; // 초기화
      _isEggAnimating = false;
      _eggAnimationFrame = 0;
      _hatchedPetAsset = null;

      // 30% 확률로 펫 획득
      final random = math.Random();
      if (random.nextDouble() < 0.3) { // 30% 확률
        final petAssets = [
          'assets/images/rpg/Egg_cat_1.png',
          'assets/images/rpg/Egg_dog_1.png',
          'assets/images/rpg/Egg_rabbit_1.png',
        ];
        _rewardPetAsset = petAssets[random.nextInt(petAssets.length)];
      }
    });
  }

  // 보상 다이얼로그 위젯
  Widget _buildRewardDialog() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.7), // 반투명 배경
        child: Center(
          child: Container(
            width: 550, // 더 넓은 다이얼로그
            height: 400,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/map_row.png'),
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 처치 성공 텍스트
                      const Text(
                        '처치 성공',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 6,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      // 보물상자
                      GestureDetector(
                        onTap: () async {
                          if (_isChestClosed && !_isChestAnimating) {
                            SoundManager().playClick();
                            await _shakeChest();
                            if (mounted) {
                              setState(() {
                                _isChestClosed = false;
                                _isChestAnimating = false;
                                SoundManager().playReward();
                              });
                            }
                            _applyRewards();
                          }
                        },
                        child: Transform.translate(
                          offset: Offset(_chestShakeX, _chestShakeY),
                          child: Image.asset(
                            _isChestClosed ? 'assets/images/Close_TreasureChest_RPG.png' : 'assets/images/Open_TreasureChest_RPG.png',
                            width: 130,
                            height: 130,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      if (!_isChestClosed) ...[
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              '+100G, +50exp',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_rewardPetAsset != null && !_isEggAnimating && _hatchedPetAsset == null) ...[
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: () {
                                  if (!_isEggAnimating) {
                                    _startEggAnimation(_rewardPetAsset!);
                                  }
                                },
                                child: Image.asset(
                                  _rewardPetAsset!,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ],
                            if (_isEggAnimating) ...[
                              const SizedBox(width: 10),
                              Image.asset(
                                _getEggAnimationFrame(),
                                width: 80,
                                height: 80,
                                fit: BoxFit.contain,
                              ),
                            ],
                            if (_hatchedPetAsset != null) ...[
                              const SizedBox(width: 10),
                              Image.asset(
                                _hatchedPetAsset!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.contain,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // 왼쪽 아래: 홈으로 버튼
                Positioned(
                  bottom: 20,
                  left: 70,
                  child: GestureDetector(
                    onTap: () {
                      SoundManager().playClick();
                      // 다이얼로그 닫고 HomeScreen으로 이동
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const HomeScreen()),
                      );
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          'assets/images/MainButton.png',
                          width: 110,
                          height: 60,
                          fit: BoxFit.contain,
                        ),
                        const Text(
                          '홈으로',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Egg 애니메이션 시작
  void _startEggAnimation(String eggAsset) {
    if (_isEggAnimating) return;

    setState(() {
      _isEggAnimating = true;
      _eggAnimationFrame = 1; // 첫 프레임부터 시작
    });

    _eggAnimationTimer?.cancel();
    _eggAnimationTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_eggAnimationFrame >= 4) {
        // 애니메이션 완료, 펫 표시
        timer.cancel();
        _eggAnimationTimer = null;
        
        // Egg 타입에 따라 펫 결정
        String petAsset;
        if (eggAsset.contains('cat')) {
          petAsset = 'assets/images/Pet_Cat.png';
        } else if (eggAsset.contains('dog')) {
          petAsset = 'assets/images/Pet_Dog.png';
        } else if (eggAsset.contains('rabbit')) {
          petAsset = 'assets/images/Pet_Rabbit.png';
        } else {
          petAsset = 'assets/images/Pet_Cat.png'; // 기본값
        }

        if (mounted) {
          setState(() {
            _isEggAnimating = false;
            _eggAnimationFrame = 0;
            _hatchedPetAsset = petAsset;
            _rewardPetAsset = null; // Egg 숨기기
          });
        }
      } else {
        // 다음 프레임으로
        if (mounted) {
          setState(() {
            _eggAnimationFrame++;
          });
        }
      }
    });
  }

  // Egg 애니메이션 프레임 경로 가져오기
  String _getEggAnimationFrame() {
    String basePath = _rewardPetAsset ?? 'assets/images/rpg/Egg_cat_1.png';
    
    // 경로에서 타입 추출
    String type = 'cat';
    if (basePath.contains('dog')) {
      type = 'dog';
    } else if (basePath.contains('rabbit')) {
      type = 'rabbit';
    }
    
    return 'assets/images/rpg/Egg_${type}_$_eggAnimationFrame.png';
  }

  // 보물상자 흔들리는 애니메이션
  Future<void> _shakeChest() async {
    if (!mounted) return;
    
    setState(() {
      _isChestAnimating = true;
    });

    final random = math.Random();
    const int shakeCount = 8; // 흔들림 횟수
    const int shakeDuration = 400; // 총 흔들림 시간 (ms)
    const int frameDuration = shakeDuration ~/ shakeCount; // 각 흔들림 프레임 시간

    for (int i = 0; i < shakeCount; i++) {
      if (!mounted) break;
      
      // 랜덤한 방향으로 흔들림
      double shakeX = (random.nextDouble() - 0.5) * 10; // -5 ~ 5
      double shakeY = (random.nextDouble() - 0.5) * 8; // -4 ~ 4
      
      setState(() {
        _chestShakeX = shakeX;
        _chestShakeY = shakeY;
      });
      
      await Future.delayed(Duration(milliseconds: frameDuration));
      
      // 원래 위치로 복귀
      if (i < shakeCount - 1) {
        setState(() {
          _chestShakeX = 0.0;
          _chestShakeY = 0.0;
        });
        await Future.delayed(Duration(milliseconds: frameDuration ~/ 2));
      }
    }
    
    // 최종적으로 원래 위치로
    if (mounted) {
      setState(() {
        _chestShakeX = 0.0;
        _chestShakeY = 0.0;
      });
    }
  }

  // 보상 획득 적용
  Future<void> _applyRewards() async {
    if (!mounted) return;

    // 임시로 골드와 경험치 업데이트
    setState(() {
      _playerAttack += 0; // 예시: 공격력 변화 없음
      _playerDefense += 0; // 예시: 방어력 변화 없음
      _playerHealth += 0; // 예시: 체력 변화 없음
      _playerMaxHealth += 0; // 예시: 최대 체력 변화 없음
    });

    // TODO: GameService를 통해 백엔드에 보상 업데이트 요청
    print('보상 적용됨: 100G, +50exp');
    if (_rewardPetAsset != null) {
      print('새로운 펫 획득: $_rewardPetAsset');
      // TODO: 펫 저장 로직 추가 (인벤토리 또는 펫 목록에 추가)
    }
  }
}

// 파티클을 그리는 CustomPainter
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;

  ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      if (!particle.isAlive()) continue;

      // 생명력에 따라 투명도 조절 (0.0~1.0 범위로 클램프)
      double alpha = 0.0;
      if (particle.maxLife > 0) {
        alpha = (particle.life / particle.maxLife).clamp(0.0, 1.0);
      }
      Color color = particle.color.withOpacity(alpha);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      // 파티클 그리기 (원형)
      canvas.drawCircle(
        Offset(particle.x, particle.y),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) {
    return true; // 항상 리페인트 (파티클이 계속 움직임)
  }
}

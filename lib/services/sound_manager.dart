import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

/// 효과음 재생을 관리하는 싱글톤 클래스
class SoundManager {
  static final SoundManager _instance = SoundManager._internal();
  factory SoundManager() => _instance;
  SoundManager._internal();

  final AudioPlayer _bgmPlayer = AudioPlayer(); // 보스 스테이지 배경음악용 별도 플레이어
  final AudioPlayer _normalBgmPlayer = AudioPlayer(); // 일반 배경음악용 별도 플레이어
  bool _soundEnabled = true;
  bool _isBossMusicPlaying = false; // 보스 스테이지 배경음악 재생 중인지 여부
  bool _isNormalBgmPlaying = false; // 일반 배경음악 재생 중인지 여부
  bool _bgmListenerSetup = false; // 배경음악 리스너 설정 여부
  Timer? _bgmCheckTimer; // 배경음악 상태 확인 타이머
  bool _isResumingBgm = false; // 배경음악 복구 중인지 여부 (중복 방지)
  
  /// 배경음악 상태 확인 및 복구
  Future<void> _checkAndResumeBgm() async {
    if (!_isBossMusicPlaying || _isResumingBgm) return;
    
    try {
      final state = _bgmPlayer.state;
      if (state == PlayerState.stopped || state == PlayerState.paused) {
        _isResumingBgm = true;
        
        // 배경음악이 중단되었으면 즉시 다시 재생
        await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
        await _bgmPlayer.setVolume(0.7);
        
        // paused 상태면 resume 시도
        if (state == PlayerState.paused) {
          await _bgmPlayer.resume();
          // resume이 작동하지 않으면 play
          await Future.delayed(const Duration(milliseconds: 30));
          if (_bgmPlayer.state != PlayerState.playing) {
            await _bgmPlayer.play(AssetSource('music/boss_stage_music.mp3'));
          }
        } else {
          // stopped 상태면 바로 play
          await _bgmPlayer.play(AssetSource('music/boss_stage_music.mp3'));
        }
        
        // 복구 완료 후 플래그 해제
        await Future.delayed(const Duration(milliseconds: 100));
        _isResumingBgm = false;
      }
    } catch (e) {
      print('배경음악 상태 확인 실패: $e');
      _isResumingBgm = false;
    }
  }

  /// 효과음 재생 헬퍼 메서드 (각 효과음마다 새로운 플레이어 생성하여 겹쳐서 재생)
  Future<void> _playSoundEffect(String assetPath, {double volume = 1.0}) async {
    if (!_soundEnabled) return;
    
    try {
      final player = AudioPlayer();
      // 효과음은 오디오 포커스를 요청하지 않도록 설정 (Android 전용)
      // AudioContext를 설정하여 효과음이 배경음악을 중단하지 않도록 함
      try {
        // Android에서 효과음이 오디오 포커스를 요청하지 않도록 설정
        await player.setAudioContext(AudioContext(
          android: AudioContextAndroid(
            audioMode: AndroidAudioMode.normal,
            audioFocus: AndroidAudioFocus.none, // 오디오 포커스를 요청하지 않음
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.game,
          ),
        ));
      } catch (e) {
        // AudioContext 설정 실패 시 무시하고 계속 진행
        print('AudioContext 설정 실패 (무시): $e');
      }
      await player.setVolume(volume);
      await player.play(AssetSource(assetPath));
      
      // 재생 완료 후 자동으로 dispose
      player.onPlayerComplete.listen((_) {
        player.dispose();
        // 효과음 재생 완료 후 배경음악 상태 확인 (보스 스테이지 배경음악만)
        if (_isBossMusicPlaying) {
          _checkAndResumeBgm();
        }
      });
      
      // 효과음 재생 시작 후 배경음악 상태 확인 (보스 스테이지 배경음악만, 더 빠르게 여러 번 확인)
      if (_isBossMusicPlaying) {
        Future.delayed(const Duration(milliseconds: 10), () {
          _checkAndResumeBgm();
        });
        Future.delayed(const Duration(milliseconds: 30), () {
          _checkAndResumeBgm();
        });
        Future.delayed(const Duration(milliseconds: 50), () {
          _checkAndResumeBgm();
        });
        Future.delayed(const Duration(milliseconds: 100), () {
          _checkAndResumeBgm();
        });
        Future.delayed(const Duration(milliseconds: 200), () {
          _checkAndResumeBgm();
        });
      }
    } catch (e) {
      print('효과음 재생 실패: $e');
    }
  }

  /// 효과음 활성화 여부
  bool get soundEnabled => _soundEnabled;
  
  /// 효과음 활성화/비활성화
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  /// 클릭 효과음 재생
  Future<void> playClick() async {
    await _playSoundEffect('music/click.mp3');
  }

  /// 보상 효과음 재생 (보물상자 클릭 시)
  Future<void> playReward() async {
    await _playSoundEffect('music/reward.mp3');
  }

  /// 게임 오버 효과음 재생 (일정 실패 시)
  Future<void> playGameOver() async {
    await _playSoundEffect('music/game_over.mp3');
  }

  /// 폭발 효과음 재생 (Cannon 이미지 표시 시)
  Future<void> playBoom() async {
    await _playSoundEffect('music/boom.mp3');
  }

  /// 검 공격 효과음 재생 (캐릭터 공격 애니메이션 시)
  Future<void> playSwordSlice() async {
    await _playSoundEffect('music/sword_slice.mp3');
  }

  /// 죽음 효과음 재생 (캐릭터/몬스터 죽을 때)
  Future<void> playDie() async {
    await _playSoundEffect('music/die.mp3');
  }

  /// 몬스터 공격1 효과음 재생
  Future<void> playAttack1() async {
    await _playSoundEffect('music/attack_1.mp3');
  }

  /// 몬스터 공격2 효과음 재생
  Future<void> playAttack2() async {
    await _playSoundEffect('music/attack_2.mp3');
  }

  /// 몬스터 공격3 효과음 재생
  Future<void> playAttack3() async {
    await _playSoundEffect('music/attack_3.mp3');
  }

  /// 일반 배경음악 재생 (반복 재생, 화면 전환 시에도 계속 재생)
  Future<void> playBackgroundMusic() async {
    if (!_soundEnabled) return;
    if (_isNormalBgmPlaying) return; // 이미 재생 중이면 무시
    
    try {
      // 보스 스테이지 배경음악이 재생 중이면 먼저 정지
      if (_isBossMusicPlaying) {
        await stopBossStageMusic();
      }
      
      _isNormalBgmPlaying = true;
      
      // 일반 배경음악에 적절한 AudioContext 설정
      try {
        await _normalBgmPlayer.setAudioContext(AudioContext(
          android: AudioContextAndroid(
            audioMode: AndroidAudioMode.normal,
            audioFocus: AndroidAudioFocus.gain, // 오디오 포커스 요청
            stayAwake: false,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.game,
          ),
        ));
      } catch (e) {
        print('일반 배경음악 AudioContext 설정 실패 (무시): $e');
      }
      
      await _normalBgmPlayer.setReleaseMode(ReleaseMode.loop); // 반복 재생
      await _normalBgmPlayer.setVolume(0.5); // 일반 배경음악 볼륨 설정
      await _normalBgmPlayer.play(AssetSource('music/background_music.wav'));
    } catch (e) {
      print('일반 배경음악 재생 실패: $e');
      _isNormalBgmPlaying = false;
    }
  }

  /// 일반 배경음악 정지 (보스 스테이지로 이동할 때만 호출)
  Future<void> stopBackgroundMusic() async {
    try {
      _isNormalBgmPlaying = false;
      await _normalBgmPlayer.stop();
    } catch (e) {
      print('일반 배경음악 정지 실패: $e');
    }
  }

  /// 보스 스테이지 배경음악 재생 (반복 재생)
  Future<void> playBossStageMusic() async {
    if (!_soundEnabled) return;
    
    try {
      // 일반 배경음악이 재생 중이면 먼저 정지
      if (_isNormalBgmPlaying) {
        await stopBackgroundMusic();
      }
      
      // 리스너를 한 번만 설정
      if (!_bgmListenerSetup) {
        _bgmListenerSetup = true;
        // 배경음악이 중단되면 즉시 자동으로 다시 재생
        _bgmPlayer.onPlayerStateChanged.listen((state) async {
          if (_isBossMusicPlaying && (state == PlayerState.stopped || state == PlayerState.paused)) {
            // 재생이 중단되면 즉시 다시 재생 (최소 지연)
            Future.delayed(const Duration(milliseconds: 10), () async {
              if (!_isBossMusicPlaying || _isResumingBgm) return;
              _isResumingBgm = true;
              try {
                await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
                await _bgmPlayer.setVolume(0.7);
                if (state == PlayerState.paused) {
                  await _bgmPlayer.resume();
                  // resume이 작동하지 않으면 play
                  await Future.delayed(const Duration(milliseconds: 30));
                  if (_bgmPlayer.state != PlayerState.playing) {
                    await _bgmPlayer.play(AssetSource('music/boss_stage_music.mp3'));
                  }
                } else {
                  await _bgmPlayer.play(AssetSource('music/boss_stage_music.mp3'));
                }
                await Future.delayed(const Duration(milliseconds: 50));
                _isResumingBgm = false;
              } catch (e) {
                print('배경음악 자동 재생 실패: $e');
                _isResumingBgm = false;
              }
            });
          }
        });
        
        // 재생 완료 시 다시 재생 (loop 모드가 작동하지 않을 경우 대비)
        _bgmPlayer.onPlayerComplete.listen((_) async {
          if (_isBossMusicPlaying) {
            try {
              await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
              await _bgmPlayer.setVolume(0.7);
              await _bgmPlayer.play(AssetSource('music/boss_stage_music.mp3'));
            } catch (e) {
              print('배경음악 자동 재생 실패: $e');
            }
          }
        });
      }
      
      _isBossMusicPlaying = true;
      
      // 배경음악에 적절한 AudioContext 설정 (오디오 포커스 유지)
      try {
        await _bgmPlayer.setAudioContext(AudioContext(
          android: AudioContextAndroid(
            audioMode: AndroidAudioMode.normal,
            audioFocus: AndroidAudioFocus.gain, // 오디오 포커스 요청
            stayAwake: false,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.game,
          ),
        ));
      } catch (e) {
        // AudioContext 설정 실패 시 무시하고 계속 진행
        print('배경음악 AudioContext 설정 실패 (무시): $e');
      }
      
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop); // 반복 재생
      await _bgmPlayer.setVolume(0.7); // 배경음악 볼륨 설정
      await _bgmPlayer.play(AssetSource('music/boss_stage_music.mp3'));
      
      // 주기적으로 배경음악 상태 확인 (0.1초마다 - 매우 빠르게)
      _bgmCheckTimer?.cancel();
      _bgmCheckTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!_isBossMusicPlaying) {
          timer.cancel();
          return;
        }
        _checkAndResumeBgm();
      });
    } catch (e) {
      print('보스 스테이지 배경음악 재생 실패: $e');
      _isBossMusicPlaying = false;
    }
  }

  /// 보스 스테이지 배경음악 정지
  Future<void> stopBossStageMusic() async {
    try {
      _isBossMusicPlaying = false;
      _bgmCheckTimer?.cancel();
      _bgmCheckTimer = null;
      await _bgmPlayer.stop();
      // 보스 스테이지에서 나오면 일반 배경음악 다시 재생
      if (!_isNormalBgmPlaying) {
        await playBackgroundMusic();
      }
    } catch (e) {
      print('보스 스테이지 배경음악 정지 실패: $e');
    }
  }

  /// 스킬 효과음 재생 (Stab)
  Future<void> playSkill() async {
    await _playSoundEffect('music/skill.mp3', volume: 3.0); // 스킬 효과음 볼륨 최대로 설정
  }

  /// 대시 효과음 재생
  Future<void> playDash() async {
    await _playSoundEffect('music/dash.mp3');
  }

  /// 리소스 정리
  void dispose() {
    _bgmCheckTimer?.cancel();
    _bgmPlayer.dispose();
    _normalBgmPlayer.dispose();
  }
}


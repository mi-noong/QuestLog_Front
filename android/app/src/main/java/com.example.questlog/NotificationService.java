package com.example.questlog;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.os.Build;
import android.os.IBinder;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.core.app.NotificationCompat;

import java.util.concurrent.TimeUnit;

public class NotificationService extends Service {
    private static final String CHANNEL_ID = "questlog_reminders";
    private static final int NOTIFICATION_ID = 1;
    private static final String TAG = "NotificationService";
    
    private Handler handler;
    private Runnable startNotificationRunnable;
    private Runnable endNotificationRunnable;
    
    private int startHour = -1;
    private int startMinute = -1;
    private int endHour = -1;
    private int endMinute = -1;
    private String startTimeText = "";
    private String endTimeText = "";
    private String title = "";
    private String startMessage = "";
    private String endMessage = "";

    @Override
    public void onCreate() {
        super.onCreate();
        handler = new Handler(Looper.getMainLooper());
        createNotificationChannel();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null) {
            String action = intent.getStringExtra("action");
            
            if ("schedule".equals(action)) {
                startHour = intent.getIntExtra("startHour", -1);
                startMinute = intent.getIntExtra("startMinute", -1);
                endHour = intent.getIntExtra("endHour", -1);
                endMinute = intent.getIntExtra("endMinute", -1);
                startTimeText = intent.getStringExtra("startTimeText");
                endTimeText = intent.getStringExtra("endTimeText");
                title = intent.getStringExtra("title");
                startMessage = intent.getStringExtra("startMessage");
                endMessage = intent.getStringExtra("endMessage");
                
                Log.d(TAG, "받은 제목: " + title);
                Log.d(TAG, "받은 시작 메시지: " + startMessage);
                Log.d(TAG, "받은 종료 메시지: " + endMessage);
                
                scheduleNotifications();
            } else if ("stop".equals(action)) {
                stopNotifications();
                stopSelf();
            }
        }
        
        // 포그라운드 서비스 시작 (권한 문제 해결을 위해 조건부)
        try {
            startForeground(NOTIFICATION_ID, createForegroundNotification());
        } catch (SecurityException e) {
            Log.w(TAG, "포그라운드 서비스 시작 실패, 일반 서비스로 실행: " + e.getMessage());
        }
        
        return START_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                "QuestLog Reminders",
                NotificationManager.IMPORTANCE_HIGH
            );
            channel.setDescription("Notifications for quest start and end times");
            
            NotificationManager manager = getSystemService(NotificationManager.class);
            manager.createNotificationChannel(channel);
        }
    }

    private Notification createForegroundNotification() {
        Intent notificationIntent = new Intent(this, MainActivity.class);
        PendingIntent pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent, PendingIntent.FLAG_IMMUTABLE
        );

        return new NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("QuestLog 알림 서비스")
            .setContentText("알림을 대기 중입니다...")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build();
    }

    private void scheduleNotifications() {
        stopNotifications(); // 기존 알림 취소
        
        long startDelay = calculateDelay(startHour, startMinute);
        long endDelay = calculateDelay(endHour, endMinute);
        
        Log.d(TAG, "시작 시간까지 남은 시간: " + TimeUnit.MILLISECONDS.toMinutes(startDelay) + "분");
        Log.d(TAG, "종료 시간까지 남은 시간: " + TimeUnit.MILLISECONDS.toMinutes(endDelay) + "분");
        
        // 시작 알림 스케줄링
        if (startDelay > 0) {
            startNotificationRunnable = () -> {
                String finalStartMessage = (startMessage != null && !startMessage.isEmpty()) 
                    ? startMessage 
                    : "시작 시간입니다! " + startTimeText;
                sendNotification(1, "퀘스트 시작", finalStartMessage);
            };
            handler.postDelayed(startNotificationRunnable, startDelay);
        }
        
        // 종료 알림 스케줄링
        if (endDelay > 0) {
            endNotificationRunnable = () -> {
                String finalEndMessage = (endMessage != null && !endMessage.isEmpty()) 
                    ? endMessage 
                    : "종료 시간입니다! " + endTimeText;
                sendNotification(2, "퀘스트 종료", finalEndMessage);
            };
            handler.postDelayed(endNotificationRunnable, endDelay);
        }
    }

    private long calculateDelay(int targetHour, int targetMinute) {
        long currentTime = System.currentTimeMillis();
        
        java.util.Calendar calendar = java.util.Calendar.getInstance();
        calendar.set(java.util.Calendar.HOUR_OF_DAY, targetHour);
        calendar.set(java.util.Calendar.MINUTE, targetMinute);
        calendar.set(java.util.Calendar.SECOND, 0);
        calendar.set(java.util.Calendar.MILLISECOND, 0);
        
        long targetTime = calendar.getTimeInMillis();
        
        // 현재 시간이 목표 시간보다 늦으면 다음날로 설정
        if (targetTime <= currentTime) {
            targetTime += 24 * 60 * 60 * 1000; // 24시간 추가
        }
        
        return targetTime - currentTime;
    }

    private void sendNotification(int id, String title, String content) {
        Intent notificationIntent = new Intent(this, MainActivity.class);
        PendingIntent pendingIntent = PendingIntent.getActivity(
            this, id, notificationIntent, PendingIntent.FLAG_IMMUTABLE
        );

        Notification notification = new NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .build();

        NotificationManager manager = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        manager.notify(id, notification);
        
        Log.d(TAG, "알림 발송: " + title);
    }

    private void stopNotifications() {
        if (startNotificationRunnable != null) {
            handler.removeCallbacks(startNotificationRunnable);
            startNotificationRunnable = null;
        }
        if (endNotificationRunnable != null) {
            handler.removeCallbacks(endNotificationRunnable);
            endNotificationRunnable = null;
        }
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        stopNotifications();
    }
}

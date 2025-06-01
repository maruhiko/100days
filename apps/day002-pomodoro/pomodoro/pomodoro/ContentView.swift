//
//  ContentView.swift
//  pomodoro
//
//  Created by teruhiko maruyama on 2025/05/31.
//

import SwiftUI
import UserNotifications
import AVFoundation
import AudioToolbox

enum TimerState {
    case work
    case break_
    case idle
}

class PomodoroTimer: ObservableObject {
    @Published var timeRemaining: Int = 25 * 60
    @Published var state: TimerState = .idle
    @Published var isRunning: Bool = false
    @Published var sessionsCompleted: Int = 0
    @Published var workDuration: Int = 25 * 60
    @Published var breakDuration: Int = 5 * 60
    @Published var autoRepeat: Bool = false
    @Published var soundEnabled: Bool = true
    @Published var bgmEnabled: Bool = false
    
    private var timer: Timer?
    private var audioPlayer: AVAudioPlayer?
    private var bgmPlayer: AVAudioPlayer?
    
    init() {
        loadSettings()
        requestNotificationPermission()
        setupAudioSession()
        setupBGM()
    }
    
    func start() {
        isRunning = true
        if state == .idle {
            state = .work
            timeRemaining = workDuration
        }
        
        if bgmEnabled {
            startBGM()
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.tick()
        }
    }
    
    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        pauseBGM()
    }
    
    func reset() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        state = .idle
        timeRemaining = workDuration
        stopBGM()
    }
    
    private func tick() {
        if timeRemaining > 0 {
            timeRemaining -= 1
        } else {
            timer?.invalidate()
            timer = nil
            isRunning = false
            
            switch state {
            case .work:
                sessionsCompleted += 1
                state = .break_
                timeRemaining = breakDuration
                sendNotification(title: "作業完了！", body: "お疲れ様でした。5分間休憩しましょう。")
                playAlertSound()
                triggerHapticFeedback()
                if autoRepeat {
                    startNextSession()
                }
            case .break_:
                state = .work
                timeRemaining = workDuration
                sendNotification(title: "休憩終了！", body: "次の作業セッションを開始しましょう。")
                playAlertSound()
                triggerHapticFeedback()
                if autoRepeat {
                    startNextSession()
                }
            case .idle:
                break
            }
        }
    }
    
    func timeString() -> String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var progress: Double {
        let total = state == .work ? workDuration : breakDuration
        return 1.0 - (Double(timeRemaining) / Double(total))
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("通知許可が得られました")
            } else {
                print("通知許可が拒否されました")
            }
        }
    }
    
    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("通知エラー: \(error)")
            }
        }
    }
    
    func updateSettings(workMinutes: Int, breakMinutes: Int, autoRepeat: Bool, soundEnabled: Bool, bgmEnabled: Bool) {
        workDuration = workMinutes * 60
        breakDuration = breakMinutes * 60
        self.autoRepeat = autoRepeat
        self.soundEnabled = soundEnabled
        self.bgmEnabled = bgmEnabled
        saveSettings()
        
        if state == .idle {
            timeRemaining = workDuration
        }
        
        if !bgmEnabled {
            stopBGM()
        }
    }
    
    private func startNextSession() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.start()
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(workDuration, forKey: "workDuration")
        UserDefaults.standard.set(breakDuration, forKey: "breakDuration")
        UserDefaults.standard.set(autoRepeat, forKey: "autoRepeat")
        UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled")
        UserDefaults.standard.set(bgmEnabled, forKey: "bgmEnabled")
    }
    
    private func loadSettings() {
        let savedWorkDuration = UserDefaults.standard.integer(forKey: "workDuration")
        let savedBreakDuration = UserDefaults.standard.integer(forKey: "breakDuration")
        let savedAutoRepeat = UserDefaults.standard.bool(forKey: "autoRepeat")
        let savedSoundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        let savedBgmEnabled = UserDefaults.standard.bool(forKey: "bgmEnabled")
        
        if savedWorkDuration > 0 {
            workDuration = savedWorkDuration
        }
        if savedBreakDuration > 0 {
            breakDuration = savedBreakDuration
        }
        autoRepeat = savedAutoRepeat
        soundEnabled = savedSoundEnabled
        bgmEnabled = savedBgmEnabled
        
        timeRemaining = workDuration
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("オーディオセッションの設定に失敗: \(error)")
        }
    }
    
    private func enableBackgroundAudio() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("バックグラウンド音声設定に失敗: \(error)")
        }
    }
    
    private func setupBGM() {
        guard let path = Bundle.main.path(forResource: "bgm", ofType: "mp3") else {
            print("BGMファイルが見つかりません。プロジェクトにbgm.mp3を追加してください。")
            return
        }
        
        do {
            bgmPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            bgmPlayer?.numberOfLoops = -1
            bgmPlayer?.volume = 0.3
            bgmPlayer?.prepareToPlay()
            print("BGMファイルを読み込みました")
        } catch {
            print("BGMの初期化に失敗: \(error)")
        }
    }
    
    private func playAlertSound() {
        guard soundEnabled else { return }
        
        AudioServicesPlaySystemSound(1005)
    }
    
    private func triggerHapticFeedback() {
        guard soundEnabled else { return }
        
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
    
    private func startBGM() {
        guard bgmEnabled, let bgmPlayer = bgmPlayer else { return }
        
        enableBackgroundAudio()
        
        if !bgmPlayer.isPlaying {
            bgmPlayer.play()
        }
    }
    
    private func pauseBGM() {
        bgmPlayer?.pause()
    }
    
    private func stopBGM() {
        bgmPlayer?.stop()
        bgmPlayer?.currentTime = 0
    }
}

struct SettingsView: View {
    @ObservedObject var pomodoroTimer: PomodoroTimer
    @Binding var isPresented: Bool
    @State private var workMinutes: Int
    @State private var breakMinutes: Int
    @State private var autoRepeat: Bool
    @State private var soundEnabled: Bool
    @State private var bgmEnabled: Bool
    
    init(pomodoroTimer: PomodoroTimer, isPresented: Binding<Bool>) {
        self.pomodoroTimer = pomodoroTimer
        self._isPresented = isPresented
        self._workMinutes = State(initialValue: pomodoroTimer.workDuration / 60)
        self._breakMinutes = State(initialValue: pomodoroTimer.breakDuration / 60)
        self._autoRepeat = State(initialValue: pomodoroTimer.autoRepeat)
        self._soundEnabled = State(initialValue: pomodoroTimer.soundEnabled)
        self._bgmEnabled = State(initialValue: pomodoroTimer.bgmEnabled)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("タイマー設定")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("作業時間")
                            .font(.headline)
                        HStack {
                            Stepper("\(workMinutes)分", value: $workMinutes, in: 1...60)
                                .font(.title2)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("休憩時間")
                            .font(.headline)
                        HStack {
                            Stepper("\(breakMinutes)分", value: $breakMinutes, in: 1...30)
                                .font(.title2)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 15) {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text("自動リピート")
                                    .font(.headline)
                                Spacer()
                                Toggle("", isOn: $autoRepeat)
                            }
                            Text("セッション終了後に自動で次のセッションを開始します")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text("サウンド・バイブレーション")
                                    .font(.headline)
                                Spacer()
                                Toggle("", isOn: $soundEnabled)
                            }
                            Text("セッション終了時にアラート音とバイブレーションで通知します")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text("BGM")
                                    .font(.headline)
                                Spacer()
                                Toggle("", isOn: $bgmEnabled)
                            }
                            Text("作業中にBGMを再生します（bgm.mp3ファイルが必要）")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(15)
                
                Spacer()
                
                HStack(spacing: 20) {
                    Button("キャンセル") {
                        isPresented = false
                    }
                    .font(.title2)
                    .foregroundColor(.red)
                    .frame(width: 120, height: 50)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(25)
                    
                    Button("保存") {
                        pomodoroTimer.updateSettings(workMinutes: workMinutes, breakMinutes: breakMinutes, autoRepeat: autoRepeat, soundEnabled: soundEnabled, bgmEnabled: bgmEnabled)
                        isPresented = false
                    }
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 120, height: 50)
                    .background(Color.blue)
                    .cornerRadius(25)
                }
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}

struct ContentView: View {
    @StateObject private var pomodoroTimer = PomodoroTimer()
    @State private var showingSettings = false
    
    var body: some View {
        VStack(spacing: 30) {
            HStack {
                Text("ポモドーロタイマー")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            
            VStack(spacing: 10) {
                Text(pomodoroTimer.state == .work ? "作業時間" : 
                     pomodoroTimer.state == .break_ ? "休憩時間" : "開始前")
                    .font(.title2)
                    .foregroundColor(pomodoroTimer.state == .work ? .red : 
                                   pomodoroTimer.state == .break_ ? .green : .gray)
                
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 20)
                        .frame(width: 250, height: 250)
                    
                    Circle()
                        .trim(from: 0, to: pomodoroTimer.progress)
                        .stroke(pomodoroTimer.state == .work ? Color.red : Color.green, 
                               style: StrokeStyle(lineWidth: 20, lineCap: .round))
                        .frame(width: 250, height: 250)
                        .rotationEffect(.degrees(-90))
                    
                    Text(pomodoroTimer.timeString())
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                }
            }
            
            HStack(spacing: 20) {
                Button(action: {
                    if pomodoroTimer.isRunning {
                        pomodoroTimer.pause()
                    } else {
                        pomodoroTimer.start()
                    }
                }) {
                    Text(pomodoroTimer.isRunning ? "一時停止" : "開始")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 120, height: 50)
                        .background(pomodoroTimer.isRunning ? Color.orange : Color.blue)
                        .cornerRadius(25)
                }
                
                Button(action: {
                    pomodoroTimer.reset()
                }) {
                    Text("リセット")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 120, height: 50)
                        .background(Color.gray)
                        .cornerRadius(25)
                }
            }
            
            VStack(spacing: 15) {
                VStack(spacing: 5) {
                    Text("完了セッション数")
                        .font(.headline)
                    Text("\(pomodoroTimer.sessionsCompleted)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                if pomodoroTimer.autoRepeat {
                    HStack {
                        Image(systemName: "repeat")
                            .foregroundColor(.green)
                        Text("自動リピート有効")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingSettings) {
            SettingsView(pomodoroTimer: pomodoroTimer, isPresented: $showingSettings)
        }
    }
}

#Preview {
    ContentView()
}

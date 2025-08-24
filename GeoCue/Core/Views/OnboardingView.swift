import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var onboardingManager: OnboardingManager
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var notificationManager: NotificationManager
    
    @State private var currentStepIndex = 0
    @State private var showingLocationPermission = false
    @State private var showingNotificationPermission = false
    @State private var animateContent = false
    
    private var currentStep: OnboardingStep {
        OnboardingStep.allCases[currentStepIndex]
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBackground),
                    Color(.systemGray6).opacity(0.3)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .hueRotation(.degrees(animateContent ? 0 : 5))
            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animateContent)
            
            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator
                
                // Main content
                mainContent
                
                // Bottom navigation
                bottomNavigation
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6)) {
                animateContent = true
            }
        }
        .sheet(isPresented: $showingLocationPermission) {
            LocationPermissionSheet()
        }
        .sheet(isPresented: $showingNotificationPermission) {
            NotificationPermissionSheet()
        }
    }
    
    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        HStack {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<OnboardingStep.allCases.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentStepIndex ? currentStep.iconColor : Color(.systemGray4))
                        .frame(width: index == currentStepIndex ? 12 : 8, height: index == currentStepIndex ? 12 : 8)
                        .scaleEffect(index == currentStepIndex ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStepIndex)
                }
            }
            
            Spacer()
            
            // Skip button (only show on first few steps)
            if currentStepIndex < 3 {
                Button(action: {
                    onboardingManager.completeOnboarding()
                }) {
                    Text("Skip")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.top, 60)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Icon
            iconSection
            
            // Text content
            textSection
            
            Spacer()
            
            // Action buttons for specific steps
            if currentStep == .locationPermission {
                locationPermissionSection
            } else if currentStep == .notifications {
                notificationPermissionSection
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .opacity(animateContent ? 1.0 : 0.0)
        .offset(y: animateContent ? 0 : 20)
        .animation(.easeInOut(duration: 0.6), value: animateContent)
    }
    
    // MARK: - Icon Section
    private var iconSection: some View {
        ZStack {
            // Background circles with different opacities for depth
            Circle()
                .fill(currentStep.iconColor.opacity(0.05))
                .frame(width: 160, height: 160)
            
            Circle()
                .fill(currentStep.iconColor.opacity(0.1))
                .frame(width: 140, height: 140)
            
            Circle()
                .fill(currentStep.iconColor.opacity(0.15))
                .frame(width: 120, height: 120)
            
            // Main icon
            Image(systemName: currentStep.icon)
                .font(.system(size: 50, weight: .medium))
                .foregroundColor(currentStep.iconColor)
                .shadow(color: currentStep.iconColor.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .scaleEffect(animateContent ? 1.0 : 0.8)
        .offset(y: animateContent ? 0 : -10)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateContent)
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                // This will create a subtle floating effect
            }
        }
    }
    
    // MARK: - Text Section
    private var textSection: some View {
        VStack(spacing: 16) {
            Text(currentStep.title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text(currentStep.subtitle)
                .font(.system(size: 18, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(animateContent ? 1.0 : 0.0)
        .offset(y: animateContent ? 0 : 30)
        .animation(.easeInOut(duration: 0.6).delay(0.2), value: animateContent)
    }
    
    // MARK: - Location Permission Section
    private var locationPermissionSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                showingLocationPermission = true
            }) {
                HStack {
                    Image(systemName: "location.fill")
                        .font(.system(size: 18, weight: .medium))
                    Text("Grant Location Access")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [currentStep.iconColor, currentStep.iconColor.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: currentStep.iconColor.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            
            Text("Required for geofencing to work")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .opacity(animateContent ? 1.0 : 0.0)
        .offset(y: animateContent ? 0 : 40)
        .animation(.easeInOut(duration: 0.6).delay(0.3), value: animateContent)
    }
    
    // MARK: - Notification Permission Section
    private var notificationPermissionSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                showingNotificationPermission = true
            }) {
                HStack {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 18, weight: .medium))
                    Text("Enable Notifications")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [currentStep.iconColor, currentStep.iconColor.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: currentStep.iconColor.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            
            Text("Get reminded when you arrive or leave")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .opacity(animateContent ? 1.0 : 0.0)
        .offset(y: animateContent ? 0 : 40)
        .animation(.easeInOut(duration: 0.6).delay(0.3), value: animateContent)
    }
    
    // MARK: - Bottom Navigation
    private var bottomNavigation: some View {
        HStack(spacing: 20) {
            // Back button
            if currentStepIndex > 0 {
                Button(action: previousStep) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.primary)
                    .frame(height: 50)
                    .padding(.horizontal, 24)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            } else {
                Spacer()
                    .frame(height: 50)
            }
            
            // Next/Get Started button
            Button(action: nextStep) {
                HStack(spacing: 8) {
                    Text(currentStep.isLastStep ? "Get Started" : "Next")
                        .font(.system(size: 16, weight: .semibold))
                    
                    if !currentStep.isLastStep {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(height: 50)
                .padding(.horizontal, 32)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [currentStep.iconColor, currentStep.iconColor.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: currentStep.iconColor.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 50)
        .opacity(animateContent ? 1.0 : 0.0)
        .offset(y: animateContent ? 0 : 50)
        .animation(.easeInOut(duration: 0.6).delay(0.4), value: animateContent)
    }
    
    // MARK: - Navigation Methods
    private func nextStep() {
        if currentStep.isLastStep {
            onboardingManager.completeOnboarding()
        } else {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                currentStepIndex += 1
                animateContent = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    animateContent = true
                }
            }
        }
    }
    
    private func previousStep() {
        if currentStepIndex > 0 {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                currentStepIndex -= 1
                animateContent = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    animateContent = true
                }
            }
        }
    }
}

// MARK: - Location Permission Sheet
struct LocationPermissionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationManager: LocationManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                Image(systemName: "location.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                VStack(spacing: 16) {
                    Text("Location Access Required")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                    
                    Text("GeoCue needs location access to monitor when you enter or leave places and send you timely reminders.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                VStack(spacing: 16) {
                    Button(action: {
                        locationManager.requestLocationPermission()
                        dismiss()
                    }) {
                        Text("Grant Access")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Not Now")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
            .navigationTitle("Location Permission")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Notification Permission Sheet
struct NotificationPermissionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var notificationManager: NotificationManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.orange)
                
                VStack(spacing: 16) {
                    Text("Enable Notifications")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                    
                    Text("Get notified exactly when you need to remember something important. Never miss a reminder again.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                VStack(spacing: 16) {
                    Button(action: {
                        notificationManager.requestNotificationPermission()
                        dismiss()
                    }) {
                        Text("Enable Notifications")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Not Now")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(OnboardingManager.shared)
        .environmentObject(LocationManager())
        .environmentObject(NotificationManager())
}

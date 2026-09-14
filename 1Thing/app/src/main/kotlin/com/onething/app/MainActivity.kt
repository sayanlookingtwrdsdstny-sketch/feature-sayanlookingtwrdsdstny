package com.onething.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import com.onething.app.data.GoalDatabase
import com.onething.app.data.GoalRepository
import com.onething.app.data.ThemeMode
import com.onething.app.data.UserPreferences
import com.onething.app.data.UserPreferencesRepository
import com.onething.app.ui.AppNavigation
import com.onething.app.ui.AppViewModelFactory
import com.onething.app.ui.theme.OneThingAppTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            val goalRepository = remember {
                GoalRepository(GoalDatabase.getDatabase(this@MainActivity).goalDao())
            }
            val preferencesRepository = remember {
                UserPreferencesRepository(this@MainActivity)
            }
            val viewModelFactory = remember {
                AppViewModelFactory(application, goalRepository, preferencesRepository)
            }

            val preferences by preferencesRepository.preferences
                .collectAsState(initial = UserPreferences())

            val darkTheme = when (preferences.themeMode) {
                ThemeMode.LIGHT -> false
                ThemeMode.DARK -> true
                ThemeMode.SYSTEM -> isSystemInDarkTheme()
            }

            OneThingAppTheme(darkTheme = darkTheme) {
                Surface(modifier = Modifier.fillMaxSize()) {
                    AppNavigation(viewModelFactory = viewModelFactory)
                }
            }
        }
    }
}

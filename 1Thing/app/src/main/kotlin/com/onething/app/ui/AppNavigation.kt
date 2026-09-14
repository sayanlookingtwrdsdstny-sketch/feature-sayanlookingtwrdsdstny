package com.onething.app.ui

import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.onething.app.R

private sealed class Destination(val route: String, val labelRes: Int, val icon: ImageVector) {
    data object Today : Destination("today", R.string.nav_today, Icons.Filled.Home)
    data object History : Destination("history", R.string.nav_history, Icons.Filled.History)
    data object Stats : Destination("stats", R.string.nav_stats, Icons.Filled.BarChart)
    data object Settings : Destination("settings", R.string.nav_settings, Icons.Filled.Settings)
}

/** Settings lives behind the top bar's icon, not the bottom nav — this app is deliberately small. */
private val bottomNavDestinations = listOf(
    Destination.Today,
    Destination.History,
    Destination.Stats
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AppNavigation(
    viewModelFactory: AppViewModelFactory,
    modifier: Modifier = Modifier
) {
    val navController = rememberNavController()
    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentDestination = backStackEntry?.destination
    val currentRoute = currentDestination?.route

    val currentTitleRes = when (currentRoute) {
        Destination.History.route -> Destination.History.labelRes
        Destination.Stats.route -> Destination.Stats.labelRes
        Destination.Settings.route -> Destination.Settings.labelRes
        else -> Destination.Today.labelRes
    }

    Scaffold(
        modifier = modifier,
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            // Container matches the screen background so the bar reads as part of the page,
            // not a separate chrome layer — one less visual seam.
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = stringResource(currentTitleRes),
                        style = MaterialTheme.typography.titleLarge
                    )
                },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background
                ),
                actions = {
                    if (currentRoute != Destination.Settings.route) {
                        // A soft tonal circle instead of a bare icon — reads as a deliberate,
                        // tappable affordance rather than a stray glyph in the corner.
                        IconButton(
                            onClick = { navController.navigate(Destination.Settings.route) },
                            colors = IconButtonDefaults.iconButtonColors(
                                containerColor = MaterialTheme.colorScheme.surfaceVariant,
                                contentColor = MaterialTheme.colorScheme.onSurfaceVariant
                            ),
                            modifier = Modifier.padding(end = 8.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Filled.Settings,
                                contentDescription = stringResource(R.string.nav_settings)
                            )
                        }
                    }
                }
            )
        },
        bottomBar = {
            // A floating, rounded-top island rather than a bar flush with the screen edge —
            // gives the chrome a lighter, more deliberate presence.
            Surface(
                color = MaterialTheme.colorScheme.surface,
                tonalElevation = 3.dp,
                shadowElevation = 8.dp,
                shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)
            ) {
                NavigationBar(
                    containerColor = MaterialTheme.colorScheme.surface,
                    tonalElevation = 0.dp,
                    modifier = Modifier.clip(RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp))
                ) {
                    bottomNavDestinations.forEach { destination ->
                        val selected = currentDestination?.hierarchy?.any { it.route == destination.route } == true
                        NavigationBarItem(
                            selected = selected,
                            onClick = {
                                navController.navigate(destination.route) {
                                    popUpTo(navController.graph.findStartDestination().id) {
                                        saveState = true
                                    }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                            icon = { Icon(destination.icon, contentDescription = null) },
                            label = { Text(stringResource(destination.labelRes)) },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = MaterialTheme.colorScheme.onSecondaryContainer,
                                selectedTextColor = MaterialTheme.colorScheme.primary,
                                indicatorColor = MaterialTheme.colorScheme.secondaryContainer,
                                unselectedIconColor = MaterialTheme.colorScheme.onSurfaceVariant,
                                unselectedTextColor = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        )
                    }
                }
            }
        }
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = Destination.Today.route,
            modifier = Modifier.padding(innerPadding)
        ) {
            composable(Destination.Today.route) {
                TodayScreen(viewModel = viewModel(factory = viewModelFactory))
            }
            composable(Destination.History.route) {
                HistoryScreen(viewModel = viewModel(factory = viewModelFactory))
            }
            composable(Destination.Stats.route) {
                StatsScreen(viewModel = viewModel(factory = viewModelFactory))
            }
            composable(Destination.Settings.route) {
                SettingsScreen(viewModel = viewModel(factory = viewModelFactory))
            }
        }
    }
}

package de.leongeorgi.rudolstadt.android

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.DisableSelection
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
internal fun ExpressiveContextMenu(
    expanded: Boolean,
    onDismissRequest: () -> Unit,
    content: @Composable ColumnScope.() -> Unit,
) {
    DropdownMenu(
        expanded = expanded,
        onDismissRequest = onDismissRequest,
        modifier = Modifier.width(256.dp),
        containerColor = Color.Transparent,
        tonalElevation = 0.dp,
        shadowElevation = 0.dp,
    ) {
        // The popup is in a separate window from any selectable article text.
        DisableSelection {
            Column(
                Modifier.fillMaxWidth().padding(4.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
                content = content,
            )
        }
    }
}

@Composable
internal fun ExpressiveMenuGroup(content: @Composable ColumnScope.() -> Unit) {
    Surface(
        shape = RoundedCornerShape(20.dp),
        color = MaterialTheme.colorScheme.surfaceContainerHigh,
        shadowElevation = 3.dp,
    ) {
        Column(
            Modifier.fillMaxWidth().padding(4.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp),
            content = content,
        )
    }
}

@Composable
internal fun ExpressiveMenuItem(
    label: String,
    icon: ImageVector,
    onClick: () -> Unit,
    enabled: Boolean = true,
    destructive: Boolean = false,
) {
    val scheme = MaterialTheme.colorScheme
    DropdownMenuItem(
        text = {
            Text(label, style = MaterialTheme.typography.bodyLarge.copy(letterSpacing = 0.sp))
        },
        leadingIcon = { Icon(icon, contentDescription = null) },
        onClick = onClick,
        modifier =
            Modifier.clip(RoundedCornerShape(12.dp))
                .background(if (destructive) scheme.errorContainer else scheme.surfaceContainer),
        enabled = enabled,
        colors =
            MenuDefaults.itemColors(
                textColor = if (destructive) scheme.onErrorContainer else scheme.onSurface,
                leadingIconColor =
                    if (destructive) scheme.onErrorContainer else scheme.onSurfaceVariant,
            ),
        contentPadding = PaddingValues(horizontal = 12.dp),
    )
}

package com.example.visionmate

class HSVColorMapper {

    fun getColorName(hsv: FloatArray): String {
        val h = hsv[0]
        val s = hsv[1]
        val v = hsv[2]

        // 1. NEUTRALS (Strict Black/White for Screens)
        // Black: Increased threshold to catch glowing screens/keys
        if (v < 0.22f) return "Black"
        
        // White: High-moderate brightness with very low saturation
        if (s < 0.15f && v > 0.55f) return "White"
        
        // 2. EARTH TONES
        val isWarm = h < 55 || h > 330
        if (isWarm && s < 0.35f && v > 0.35f) {
            return when {
                v > 0.85f -> "Cream"
                v > 0.70f -> "Beige"
                v > 0.50f -> "Tan"
                else -> "Brown"
            }
        }

        // Grey: Narrowed down to avoid confusion with Black
        if (s < 0.18f) {
            return if (v > 0.45f) "Grey" else "Black"
        }

        // 3. MAIN COLORS
        val base = when {
            h < 15 || h >= 345 -> "Red"
            h < 45 -> "Orange"
            h < 75 -> "Yellow"
            h < 165 -> "Green"
            h < 200 -> "similar to Blue"
            h < 265 -> "Blue"
            h < 305 -> "Purple"
            h < 345 -> "Pink"
            else -> "Red"
        }

        // 4. SHADE REFINEMENT
        return when (base) {
            "Red" -> if (v < 0.45f) "Maroon" else "Red"
            "Blue" -> when {
                v < 0.40f -> "Dark Blue"
                v > 0.75f -> "Light Blue"
                else -> "Blue"
            }
            "Green" -> when {
                v < 0.40f -> "Dark Green"
                v > 0.75f -> "Light Green"
                else -> "Green"
            }
            "Pink" -> when {
                v > 0.85f -> "Baby Pink"
                s < 0.45f -> "Pale Pink"
                else -> "Pink"
            }
            "Yellow" -> if (s < 0.50f) "Mustard" else "Yellow"
            "Orange" -> if (v < 0.50f) "Brown" else "Orange"
            else -> base
        }
    }
}

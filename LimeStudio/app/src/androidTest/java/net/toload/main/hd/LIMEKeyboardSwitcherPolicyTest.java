/*
 * Copyright 2025, The LimeIME Open Source Project
 */
package net.toload.main.hd;

import androidx.test.ext.junit.runners.AndroidJUnit4;

import net.toload.main.hd.data.Keyboard;

import org.junit.Test;
import org.junit.runner.RunWith;

import static org.junit.Assert.*;

/**
 * Tests keyboard selection policy that should not depend on per-IM legacy
 * English layout fields.
 */
@RunWith(AndroidJUnit4.class)
public class LIMEKeyboardSwitcherPolicyTest {

    @Test
    public void englishModeIgnoresKeyboardTableEnglishLayoutFields() throws Exception {
        Keyboard keyboard = new Keyboard();
        keyboard.setEngkb("lime_abc");
        keyboard.setEngshiftkb("lime_abc_shift");

        assertEquals("lime_english", LIMEKeyboardSwitcher.resolveEnglishLayoutId(keyboard, false, false));
        assertEquals("lime_english_shift", LIMEKeyboardSwitcher.resolveEnglishLayoutId(keyboard, false, true));
        assertEquals("lime_english_number", LIMEKeyboardSwitcher.resolveEnglishLayoutId(keyboard, true, false));
        assertEquals("lime_english_number_shift", LIMEKeyboardSwitcher.resolveEnglishLayoutId(keyboard, true, true));
    }
}

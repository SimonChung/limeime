/*
 * Copyright 2025, The LimeIME Open Source Project
 */
package net.toload.main.hd;

import android.content.Context;
import android.util.AttributeSet;
import android.util.Xml;

import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.xmlpull.v1.XmlPullParser;

import java.util.ArrayList;
import java.util.List;

import static org.junit.Assert.*;

/**
 * Tests keyboard XML resources whose static key definitions are user-visible
 * behavior.
 */
@RunWith(AndroidJUnit4.class)
public class KeyboardLayoutResourceTest {

    private static final String LIME_ATTR_NS = "http://schemas.android.com/apk/res-auto";
    private static final String ANDROID_ATTR_NS = "http://schemas.android.com/apk/res/android";

    @Test
    public void hsLayoutsUseLowercaseUnshiftedAndUppercaseShiftedLetterCodesAndLabels() {
        Context context = InstrumentationRegistry.getInstrumentation().getTargetContext();

        assertLetterKeyCodes(context, R.xml.lime_hs, false);
        assertLetterKeyCodes(context, R.xml.lime_hs_shift, true);
    }

    @Test
    public void customThemeCandidateEmojiIconsUseThemeTintInNormalState() {
        Context context = InstrumentationRegistry.getInstrumentation().getTargetContext();

        assertVectorPaintUsesOnlyColor(context, R.drawable.sym_candidate_emoji_pink, R.color.pink_hl);
        assertVectorPaintUsesOnlyColor(context, R.drawable.sym_candidate_emoji_tech_blue, R.color.tech_blue_hl);
        assertVectorPaintUsesOnlyColor(context, R.drawable.sym_candidate_emoji_fashion_purple, R.color.fashion_purple_hl);
        assertVectorPaintUsesOnlyColor(context, R.drawable.sym_candidate_emoji_relax_green, R.color.relax_green_hl);
    }

    private void assertLetterKeyCodes(Context context, int layoutId, boolean shouldBeUppercase) {
        List<KeyDefinition> letterKeys = readLetterKeys(context, layoutId);
        assertFalse("HS layout should contain Latin letter keys", letterKeys.isEmpty());

        for (KeyDefinition key : letterKeys) {
            if (shouldBeUppercase) {
                assertTrue("Shifted HS letter should emit uppercase code: " + key.code,
                        key.code >= 'A' && key.code <= 'Z');
                assertEquals("Shifted HS letter should show uppercase label",
                        key.label.toUpperCase(), key.label);
            } else {
                assertTrue("Unshifted HS letter should emit lowercase code: " + key.code,
                        key.code >= 'a' && key.code <= 'z');
                assertEquals("Unshifted HS letter should show lowercase label",
                        key.label.toLowerCase(), key.label);
            }
        }
    }

    private List<KeyDefinition> readLetterKeys(Context context, int layoutId) {
        List<KeyDefinition> keys = new ArrayList<>();
        try {
            XmlPullParser parser = context.getResources().getXml(layoutId);
            int eventType;
            while ((eventType = parser.next()) != XmlPullParser.END_DOCUMENT) {
                if (eventType != XmlPullParser.START_TAG || !"Key".equals(parser.getName())) {
                    continue;
                }

                String value = parser.getAttributeValue(LIME_ATTR_NS, "codes");
                if (value == null || value.isEmpty() || value.contains(",")) {
                    continue;
                }

                int code = Integer.parseInt(value);
                String label = parser.getAttributeValue(LIME_ATTR_NS, "keyLabel");
                if (label != null && label.length() == 1 &&
                        ((code >= 'A' && code <= 'Z') || (code >= 'a' && code <= 'z'))) {
                    keys.add(new KeyDefinition(code, label));
                }
            }
        } catch (Exception e) {
            fail("Unable to read keyboard XML resource " + layoutId + ": " + e.getMessage());
        }
        return keys;
    }

    private void assertVectorPaintUsesOnlyColor(Context context, int drawableId, int expectedColorId) {
        try {
            XmlPullParser parser = context.getResources().getXml(drawableId);
            int paintedPathCount = 0;
            int eventType;
            while ((eventType = parser.next()) != XmlPullParser.END_DOCUMENT) {
                if (eventType != XmlPullParser.START_TAG || !"path".equals(parser.getName())) {
                    continue;
                }

                paintedPathCount += assertPaintAttributeUsesOnlyColor(
                        parser, drawableId, "fillColor", expectedColorId);
                paintedPathCount += assertPaintAttributeUsesOnlyColor(
                        parser, drawableId, "strokeColor", expectedColorId);
            }
            assertTrue("Vector should contain painted paths: " + drawableId, paintedPathCount > 0);
        } catch (Exception e) {
            fail("Unable to read vector drawable " + drawableId + ": " + e.getMessage());
        }
    }

    private int assertPaintAttributeUsesOnlyColor(
            XmlPullParser parser, int drawableId, String attrName, int expectedColorId) {
        String value = parser.getAttributeValue(ANDROID_ATTR_NS, attrName);
        if (value == null || "@android:color/transparent".equals(value)) {
            return 0;
        }

        AttributeSet attributes = Xml.asAttributeSet(parser);
        int colorId = attributes.getAttributeResourceValue(ANDROID_ATTR_NS, attrName, 0);
        if (colorId == android.R.color.transparent) {
            return 0;
        }
        assertEquals("Drawable " + drawableId + " " + attrName + " should use theme color",
                expectedColorId, colorId);
        return 1;
    }

    private static class KeyDefinition {
        final int code;
        final String label;

        KeyDefinition(int code, String label) {
            this.code = code;
            this.label = label;
        }
    }
}

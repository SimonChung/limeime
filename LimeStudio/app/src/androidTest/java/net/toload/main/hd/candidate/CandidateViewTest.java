package net.toload.main.hd.candidate;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import androidx.test.ext.junit.runners.AndroidJUnit4;

import org.junit.Test;
import org.junit.runner.RunWith;

@RunWith(AndroidJUnit4.class)
public class CandidateViewTest {

    @Test
    public void shouldShowLimeToastWhenAnchorIsAttachedEvenIfCandidateRowIsHidden() {
        assertTrue(CandidateView.shouldShowLimeToast(true, "大易"));
    }

    @Test
    public void shouldNotShowLimeToastWithoutAttachedAnchorOrText() {
        assertFalse(CandidateView.shouldShowLimeToast(false, "大易"));
        assertFalse(CandidateView.shouldShowLimeToast(true, null));
        assertFalse(CandidateView.shouldShowLimeToast(true, ""));
    }
}

package net.toload.main.hd;

import static org.junit.Assert.assertTrue;

import net.toload.main.hd.voice.AndroidSpeechRecognizerAdapter;
import net.toload.main.hd.voice.DictationResultListener;
import net.toload.main.hd.voice.DictationState;
import net.toload.main.hd.voice.SpeechRecognizerAdapter;

import org.junit.Test;
import org.junit.runner.RunWith;

import androidx.test.ext.junit.runners.AndroidJUnit4;

@RunWith(AndroidJUnit4.class)
public class SpeechRecognizerAdapterContractTest {

    @Test
    public void adapterAndDictationContractsExist() {
        assertTrue(SpeechRecognizerAdapter.class.isInterface());
        assertTrue(DictationResultListener.class.isInterface());
        assertTrue(AndroidSpeechRecognizerAdapter.class.getName().contains("AndroidSpeechRecognizerAdapter"));
        assertTrue(DictationState.IDLE.ordinal() >= 0);
    }
}

package net.toload.main.hd;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

import android.content.Intent;
import android.os.Bundle;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;

import androidx.test.ext.junit.runners.AndroidJUnit4;

import net.toload.main.hd.voice.DictationResultListener;
import net.toload.main.hd.voice.DictationState;
import net.toload.main.hd.voice.LIMEDictationController;
import net.toload.main.hd.voice.SpeechRecognizerAdapter;

import org.junit.Test;
import org.junit.runner.RunWith;

import java.util.ArrayList;
import java.util.List;

@RunWith(AndroidJUnit4.class)
public class LIMEDictationControllerTest {

    @Test
    public void startCreatesRecognizerIntentAndMovesToListening() {
        FakeRecognizerAdapter adapter = new FakeRecognizerAdapter();
        RecordingListener listener = new RecordingListener();
        LIMEDictationController controller = new LIMEDictationController(adapter, listener);

        controller.start("zh-TW");

        assertTrue(controller.isActive());
        assertEquals(DictationState.LISTENING, controller.getState());
        assertNotNull(adapter.listener);
        assertNotNull(adapter.lastIntent);
        assertEquals(RecognizerIntent.ACTION_RECOGNIZE_SPEECH, adapter.lastIntent.getAction());
        assertEquals("zh-TW", adapter.lastIntent.getStringExtra(RecognizerIntent.EXTRA_LANGUAGE));
        assertTrue(adapter.lastIntent.getBooleanExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false));
        assertEquals(DictationState.LISTENING, listener.states.get(0));
    }

    @Test
    public void partialResultPublishesPartialText() {
        FakeRecognizerAdapter adapter = new FakeRecognizerAdapter();
        RecordingListener listener = new RecordingListener();
        LIMEDictationController controller = new LIMEDictationController(adapter, listener);
        controller.start("zh-TW");

        adapter.listener.onPartialResults(bundleWithText("這是測試"));

        assertEquals(DictationState.PARTIAL, controller.getState());
        assertEquals("這是測試", listener.partials.get(0));
    }

    @Test
    public void finalResultPublishesFinalTextOnceAndStopsActiveSession() {
        FakeRecognizerAdapter adapter = new FakeRecognizerAdapter();
        RecordingListener listener = new RecordingListener();
        LIMEDictationController controller = new LIMEDictationController(adapter, listener);
        controller.start("zh-TW");

        adapter.listener.onResults(bundleWithText("繁體中文"));
        adapter.listener.onResults(bundleWithText("第二次"));

        assertTrue(adapter.stopped);
        assertFalse(controller.isActive());
        assertEquals(DictationState.FINALIZING, controller.getState());
        assertEquals(1, listener.finals.size());
        assertEquals("繁體中文", listener.finals.get(0));
    }

    @Test
    public void cancelCancelsAdapterAndPublishesCancelledState() {
        FakeRecognizerAdapter adapter = new FakeRecognizerAdapter();
        RecordingListener listener = new RecordingListener();
        LIMEDictationController controller = new LIMEDictationController(adapter, listener);
        controller.start("zh-TW");

        controller.cancel();

        assertTrue(adapter.cancelled);
        assertFalse(controller.isActive());
        assertEquals(DictationState.CANCELLED, controller.getState());
        assertTrue(listener.cancelled);
    }

    @Test
    public void recognizerErrorDoesNotRequestFallback() {
        FakeRecognizerAdapter adapter = new FakeRecognizerAdapter();
        RecordingListener listener = new RecordingListener();
        LIMEDictationController controller = new LIMEDictationController(adapter, listener);
        controller.start("zh-TW");

        adapter.listener.onError(SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS);

        assertTrue(adapter.cancelled);
        assertFalse(controller.isActive());
        assertEquals(DictationState.ERROR, controller.getState());
        assertEquals(SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS, listener.errorCode);
        assertFalse(listener.shouldFallback);
    }

    @Test
    public void lateRecognizerErrorAfterFinalResultIsIgnored() {
        FakeRecognizerAdapter adapter = new FakeRecognizerAdapter();
        RecordingListener listener = new RecordingListener();
        LIMEDictationController controller = new LIMEDictationController(adapter, listener);
        controller.start("zh-TW");

        adapter.listener.onResults(bundleWithText("繁體中文"));
        adapter.listener.onError(SpeechRecognizer.ERROR_SPEECH_TIMEOUT);

        assertEquals(1, listener.finals.size());
        assertEquals("繁體中文", listener.finals.get(0));
        assertEquals(0, listener.errorCode);
        assertFalse(listener.shouldFallback);
    }

    @Test
    public void unavailableRecognizerErrorsWithoutStartingAdapter() {
        FakeRecognizerAdapter adapter = new FakeRecognizerAdapter();
        adapter.available = false;
        RecordingListener listener = new RecordingListener();
        LIMEDictationController controller = new LIMEDictationController(adapter, listener);

        controller.start("zh-TW");

        assertFalse(controller.isActive());
        assertEquals(DictationState.ERROR, controller.getState());
        assertEquals(SpeechRecognizer.ERROR_CLIENT, listener.errorCode);
        assertTrue(listener.shouldFallback);
        assertFalse(adapter.started);
    }

    private Bundle bundleWithText(String text) {
        Bundle bundle = new Bundle();
        ArrayList<String> matches = new ArrayList<>();
        matches.add(text);
        bundle.putStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION, matches);
        return bundle;
    }

    private static class FakeRecognizerAdapter implements SpeechRecognizerAdapter {
        private RecognitionListener listener;
        private Intent lastIntent;
        private boolean available = true;
        private boolean started;
        private boolean stopped;
        private boolean cancelled;

        @Override
        public void setRecognitionListener(RecognitionListener listener) {
            this.listener = listener;
        }

        @Override
        public void startListening(Intent intent) {
            this.lastIntent = intent;
            this.started = true;
        }

        @Override
        public void stopListening() {
            this.stopped = true;
        }

        @Override
        public void cancel() {
            this.cancelled = true;
        }

        @Override
        public void destroy() {
        }

        @Override
        public boolean isRecognitionAvailable() {
            return available;
        }
    }

    private static class RecordingListener implements DictationResultListener {
        private final List<DictationState> states = new ArrayList<>();
        private final List<String> partials = new ArrayList<>();
        private final List<String> finals = new ArrayList<>();
        private int errorCode = 0;
        private boolean shouldFallback;
        private boolean cancelled;

        @Override
        public void onDictationStateChanged(DictationState state) {
            states.add(state);
        }

        @Override
        public void onDictationPartialText(String text) {
            partials.add(text);
        }

        @Override
        public void onDictationFinalText(String text) {
            finals.add(text);
        }

        @Override
        public void onDictationError(int errorCode, boolean shouldFallback) {
            this.errorCode = errorCode;
            this.shouldFallback = shouldFallback;
        }

        @Override
        public void onDictationCancelled() {
            this.cancelled = true;
        }
    }
}

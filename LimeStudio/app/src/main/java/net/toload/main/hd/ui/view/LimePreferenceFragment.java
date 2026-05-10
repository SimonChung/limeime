package net.toload.main.hd.ui.view;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;

public class LimePreferenceFragment extends Fragment {

    public static LimePreferenceFragment newInstance() {
        return new LimePreferenceFragment();
    }

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container,
                             @Nullable Bundle savedInstanceState) {
        TextView tv = new TextView(requireContext());
        tv.setText("喜好設定 (coming soon)");
        tv.setPadding(32, 32, 32, 32);
        return tv;
    }
}

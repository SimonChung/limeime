package net.toload.main.hd.ui.view;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;

public class ImListFragment extends Fragment {

    public static ImListFragment newInstance() {
        return new ImListFragment();
    }

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container,
                             @Nullable Bundle savedInstanceState) {
        TextView tv = new TextView(requireContext());
        tv.setText("輸入法 (coming soon)");
        tv.setPadding(32, 32, 32, 32);
        return tv;
    }
}

package net.toload.main.hd.ui.view;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.preference.PreferenceManager;

import com.google.android.material.appbar.MaterialToolbar;
import com.google.android.material.button.MaterialButton;
import com.google.android.material.switchmaterial.SwitchMaterial;

import net.toload.main.hd.R;
import net.toload.main.hd.data.ImConfig;
import net.toload.main.hd.data.Keyboard;
import net.toload.main.hd.ui.LIMESettings;
import net.toload.main.hd.ui.controller.ManageImController;

import java.util.List;

/**
 * Per-IM detail screen shown in the detail pane of TwoPaneHostFragment.
 *
 * <p>Displays IM info (name, record count), keyboard layout picker,
 * link to ManageImFragment, options, and a remove button stub.
 */
public class ImDetailFragment extends Fragment {

    private static final String TAG = "ImDetailFragment";
    private static final String ARG_IM_CODE = "im_code";
    private static final String ARG_IM_DESC = "im_desc";

    private Activity activity;
    private ManageImController manageImController;

    private String tableCode;
    private String imDesc;

    private TextView tvImName;
    private TextView tvImRecords;
    private TextView tvKeyboardValue;

    public static ImDetailFragment newInstance(ImConfig im) {
        ImDetailFragment f = new ImDetailFragment();
        Bundle args = new Bundle();
        args.putString(ARG_IM_CODE, im.getCode());
        args.putString(ARG_IM_DESC, im.getDesc());
        f.setArguments(args);
        return f;
    }

    @Override
    public void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        if (getArguments() != null) {
            tableCode = getArguments().getString(ARG_IM_CODE);
            imDesc = getArguments().getString(ARG_IM_DESC);
        }
    }

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container,
                             @Nullable Bundle savedInstanceState) {
        activity = getActivity();

        if (activity instanceof LIMESettings) {
            manageImController = ((LIMESettings) activity).getManageImController();
        } else {
            Log.w(TAG, "Activity is not LIMESettings; ManageImController unavailable");
        }

        View rootView = inflater.inflate(R.layout.fragment_im_detail, container, false);

        // Toolbar with back navigation
        MaterialToolbar toolbar = rootView.findViewById(R.id.im_detail_toolbar);
        toolbar.setTitle(imDesc != null ? imDesc : "");
        toolbar.setNavigationOnClickListener(v -> {
            Fragment host = getParentFragment();
            if (host != null) {
                host.getChildFragmentManager().popBackStack();
            }
        });

        tvImName = rootView.findViewById(R.id.tv_im_name);
        tvImRecords = rootView.findViewById(R.id.tv_im_records);
        tvKeyboardValue = rootView.findViewById(R.id.tv_keyboard_value);

        if (imDesc != null) {
            tvImName.setText(imDesc);
        }

        // Keyboard row click -> show picker
        LinearLayout rowKeyboard = rootView.findViewById(R.id.row_keyboard);
        rowKeyboard.setOnClickListener(v -> showKeyboardPicker());

        // 字根資料表 row click -> navigate to ManageImFragment
        LinearLayout rowManageTable = rootView.findViewById(R.id.row_manage_table);
        rowManageTable.setOnClickListener(v -> {
            Fragment parent = getParentFragment();
            if (parent instanceof TwoPaneHostFragment && tableCode != null) {
                ((TwoPaneHostFragment) parent).navigateToDetail(
                        ManageImFragment.newInstance(1, tableCode));
            }
        });

        // 備份選項 switch - bound to SharedPreferences
        SwitchMaterial switchBackup = rootView.findViewById(R.id.switch_backup_on_delete);
        if (tableCode != null) {
            SharedPreferences prefs = PreferenceManager.getDefaultSharedPreferences(requireContext());
            boolean backupPref = prefs.getBoolean("backup_on_delete_" + tableCode, false);
            switchBackup.setChecked(backupPref);
            switchBackup.setOnCheckedChangeListener((btn, checked) ->
                    PreferenceManager.getDefaultSharedPreferences(requireContext())
                            .edit()
                            .putBoolean("backup_on_delete_" + tableCode, checked)
                            .apply());
        }

        // 移除輸入法 button
        MaterialButton btnRemove = rootView.findViewById(R.id.btn_remove_im);
        btnRemove.setOnClickListener(v -> showRemoveConfirmDialog());

        // Load async data
        loadRecordCount();
        loadCurrentKeyboard();

        return rootView;
    }

    private void loadRecordCount() {
        final ManageImController ctrl = manageImController;
        final Activity act = activity;
        final String table = tableCode;
        if (ctrl == null || table == null) return;

        new Thread(() -> {
            final int count = ctrl.countRecords(table);
            if (act == null) return;
            act.runOnUiThread(() -> {
                if (!isAdded() || activity == null || tvImRecords == null) return;
                tvImRecords.setText(String.valueOf(count));
            });
        }).start();
    }

    private void loadCurrentKeyboard() {
        final ManageImController ctrl = manageImController;
        final Activity act = activity;
        final String table = tableCode;
        if (ctrl == null || table == null) return;

        new Thread(() -> {
            final Keyboard kb = ctrl.getCurrentKeyboard(table);
            if (act == null) return;
            act.runOnUiThread(() -> {
                if (!isAdded() || activity == null || tvKeyboardValue == null) return;
                if (kb != null && kb.getDesc() != null && !kb.getDesc().isEmpty()) {
                    tvKeyboardValue.setText(kb.getDesc());
                } else {
                    tvKeyboardValue.setText(R.string.im_detail_keyboard_default);
                }
            });
        }).start();
    }

    private void showKeyboardPicker() {
        final ManageImController ctrl = manageImController;
        final Activity act = activity;
        if (ctrl == null || act == null || tableCode == null) return;

        new Thread(() -> {
            final List<Keyboard> keyboards = ctrl.getKeyboardList();
            if (act == null) return;
            act.runOnUiThread(() -> {
                if (!isAdded() || activity == null) return;
                if (keyboards == null || keyboards.isEmpty()) return;

                String[] names = new String[keyboards.size()];
                for (int i = 0; i < keyboards.size(); i++) {
                    names[i] = keyboards.get(i).getDesc();
                }

                final String tbl = tableCode;
                new AlertDialog.Builder(activity)
                        .setTitle(R.string.im_detail_keyboard_picker_title)
                        .setItems(names, (dialog, which) -> {
                            Keyboard selected = keyboards.get(which);
                            if (tvKeyboardValue != null) {
                                tvKeyboardValue.setText(selected.getDesc());
                            }
                            new Thread(() -> ctrl.setIMKeyboard(tbl, selected)).start();
                        })
                        .setNegativeButton(android.R.string.cancel, null)
                        .show();
            });
        }).start();
    }

    private void showRemoveConfirmDialog() {
        if (activity == null) return;
        new AlertDialog.Builder(activity)
                .setMessage(R.string.im_detail_remove_confirm)
                .setPositiveButton(android.R.string.ok, (dialog, which) ->
                        android.widget.Toast.makeText(activity, "功能開發中",
                                android.widget.Toast.LENGTH_SHORT).show())
                .setNegativeButton(android.R.string.cancel, null)
                .show();
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        activity = null;
        manageImController = null;
        tvImName = null;
        tvImRecords = null;
        tvKeyboardValue = null;
    }
}

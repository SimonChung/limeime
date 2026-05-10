/*
 *
 *  *
 *  **    Copyright 2025, The LimeIME Open Source Project
 *  **
 *  **    Project Url: http://github.com/lime-ime/limeime/
 *  **                 http://android.toload.net/
 *  **
 *  **    This program is free software: you can redistribute it and/or modify
 *  **    it under the terms of the GNU General Public License as published by
 *  **    the Free Software Foundation, either version 3 of the License, or
 *  **    (at your option) any later version.
 *  *
 *  **    This program is distributed in the hope that it will be useful,
 *  **    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  **    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  **    GNU General Public License for more details.
 *  *
 *  **    You should have received a copy of the GNU General Public License
 *  **    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *  *
 *
 */

package net.toload.main.hd.ui.view;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.provider.OpenableColumns;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.preference.PreferenceManager;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.google.android.material.button.MaterialButton;
import com.google.android.material.switchmaterial.SwitchMaterial;

import net.toload.main.hd.R;
import net.toload.main.hd.global.LIME;
import net.toload.main.hd.ui.LIMESettings;
import net.toload.main.hd.ui.controller.SetupImController;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;

/**
 * Fragment showing expandable per-IM download/import cards.
 * Replaces ImListFragment under Tab 1 (輸入法).
 */
public class ImInstallFragment extends Fragment {

    private static final String TAG = "ImInstallFragment";

    private SetupImController setupImController;
    private Activity activity;

    // File picker launchers
    private ActivityResultLauncher<Intent> limedbLauncher;
    private ActivityResultLauncher<Intent> txtLauncher;

    // State for pending picker result
    private String pendingTableName;
    private boolean pendingIsRelated;

    public static ImInstallFragment newInstance() {
        return new ImInstallFragment();
    }

    @Override
    public void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        limedbLauncher = registerForActivityResult(
                new ActivityResultContracts.StartActivityForResult(),
                result -> {
                    if (result.getResultCode() == Activity.RESULT_OK && result.getData() != null) {
                        Uri uri = result.getData().getData();
                        if (uri != null) {
                            Activity act = activity;
                            SetupImController ctrl = setupImController;
                            String tbl = pendingTableName;
                            boolean rel = pendingIsRelated;
                            boolean restore = getRestorePref(tbl);
                            new Thread(() -> {
                                File file = saveUriToFile(uri, act);
                                if (file != null && ctrl != null) {
                                    if (rel) ctrl.importZippedDbRelated(file);
                                    else ctrl.importZippedDb(file, tbl, restore);
                                }
                            }).start();
                        }
                    }
                });

        txtLauncher = registerForActivityResult(
                new ActivityResultContracts.StartActivityForResult(),
                result -> {
                    if (result.getResultCode() == Activity.RESULT_OK && result.getData() != null) {
                        Uri uri = result.getData().getData();
                        if (uri != null) {
                            Activity act = activity;
                            SetupImController ctrl = setupImController;
                            String tbl = pendingTableName;
                            boolean restore = getRestorePref(tbl);
                            new Thread(() -> {
                                File file = saveUriToFile(uri, act);
                                if (file != null && ctrl != null) {
                                    ctrl.importTxtTable(file, tbl, restore);
                                }
                            }).start();
                        }
                    }
                });
    }

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container,
                             @Nullable Bundle savedInstanceState) {
        activity = getActivity();

        if (activity instanceof LIMESettings) {
            setupImController = ((LIMESettings) activity).getSetupImController();
        } else {
            Log.w(TAG, "Activity is not LIMESettings; SetupImController unavailable");
        }

        View rootView = inflater.inflate(R.layout.fragment_im_install, container, false);

        RecyclerView recyclerView = rootView.findViewById(R.id.im_install_list);
        recyclerView.setLayoutManager(new LinearLayoutManager(requireContext()));
        recyclerView.setAdapter(new ImFamilyAdapter(buildFamilyList()));

        return rootView;
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        activity = null;
        setupImController = null;
    }

    // -------- Restore-learning preference --------

    private boolean getRestorePref(String tableName) {
        SharedPreferences prefs = PreferenceManager.getDefaultSharedPreferences(requireContext());
        return prefs.getBoolean("restore_on_import_" + tableName, true);
    }

    private void setRestorePref(String tableName, boolean value) {
        PreferenceManager.getDefaultSharedPreferences(requireContext())
                .edit()
                .putBoolean("restore_on_import_" + tableName, value)
                .apply();
    }

    // -------- File picker launchers --------

    private void launchLimedbPicker(String tableName, boolean isRelated) {
        pendingTableName = tableName;
        pendingIsRelated = isRelated;
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("*/*");
        limedbLauncher.launch(intent);
    }

    private void launchTxtPicker(String tableName) {
        pendingTableName = tableName;
        pendingIsRelated = false;
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("*/*");
        txtLauncher.launch(intent);
    }

    // -------- URI → File helper (verbatim from SetupImLoadDialog) --------

    private File saveUriToFile(Uri uri, Activity act) {
        if (act == null) return null;
        try (InputStream inputStream = act.getContentResolver().openInputStream(uri)) {
            if (inputStream == null) return null;
            String fileName = getFileName(uri, act);
            File file = new File(act.getCacheDir(), fileName);
            try (OutputStream outputStream = new FileOutputStream(file)) {
                byte[] buffer = new byte[LIME.BUFFER_SIZE_1KB];
                int length;
                while ((length = inputStream.read(buffer)) > 0) {
                    outputStream.write(buffer, 0, length);
                }
            }
            return file;
        } catch (Exception e) {
            Log.e(TAG, "Error saving file from URI", e);
            return null;
        }
    }

    private String getFileName(Uri uri, Activity act) {
        if (act == null) return "tmpfile";
        String result = null;
        if ("content".equals(uri.getScheme())) {
            try (Cursor cursor = act.getContentResolver().query(uri, null, null, null, null)) {
                if (cursor != null && cursor.moveToFirst()) {
                    int nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                    if (nameIndex != -1) {
                        result = cursor.getString(nameIndex);
                    }
                }
            }
        }
        if (result == null) {
            result = uri.getPath();
            if (result != null) {
                int cut = result.lastIndexOf('/');
                if (cut != -1) result = result.substring(cut + 1);
            } else {
                result = "tmpfile";
            }
        }
        return result;
    }

    // -------- Data model --------

    private static class CloudVariant {
        final int labelResId;
        final String count;
        final String url;

        CloudVariant(int labelResId, String count, String url) {
            this.labelResId = labelResId;
            this.count = count;
            this.url = url;
        }
    }

    private static class ImFamily {
        final String tableName;
        final String displayTitle;
        final List<CloudVariant> cloudVariants;
        final boolean hasRestoreSwitch;
        final boolean isRelated;
        final boolean isCustom;

        ImFamily(String tableName, String displayTitle, List<CloudVariant> cloudVariants,
                 boolean hasRestoreSwitch, boolean isRelated, boolean isCustom) {
            this.tableName = tableName;
            this.displayTitle = displayTitle;
            this.cloudVariants = cloudVariants;
            this.hasRestoreSwitch = hasRestoreSwitch;
            this.isRelated = isRelated;
            this.isCustom = isCustom;
        }
    }

    private List<ImFamily> buildFamilyList() {
        List<ImFamily> list = new ArrayList<>();

        // 注音
        List<CloudVariant> phonetic = new ArrayList<>();
        phonetic.add(new CloudVariant(R.string.l3_im_download_from_phonetic_big5, "15,945",
                LIME.DATABASE_CLOUD_IM_PHONETIC_BIG5));
        phonetic.add(new CloudVariant(R.string.l3_im_download_from_phonetic, "34,838",
                LIME.DATABASE_CLOUD_IM_PHONETIC));
        phonetic.add(new CloudVariant(R.string.l3_im_download_from_phonetic_adv_big5, "76,122",
                LIME.DATABASE_CLOUD_IM_PHONETICCOMPLETE_BIG5));
        phonetic.add(new CloudVariant(R.string.l3_im_download_from_phonetic_adv, "95,029",
                LIME.DATABASE_CLOUD_IM_PHONETICCOMPLETE));
        list.add(new ImFamily(LIME.DB_TABLE_PHONETIC, "注音", phonetic, true, false, false));

        // 倉頡
        List<CloudVariant> cj = new ArrayList<>();
        cj.add(new CloudVariant(R.string.l3_im_download_from_cj_big5, "13,859",
                LIME.DATABASE_CLOUD_IM_CJ_BIG5));
        cj.add(new CloudVariant(R.string.l3_im_download_from_cj, "28,596",
                LIME.DATABASE_CLOUD_IM_CJ));
        cj.add(new CloudVariant(R.string.l3_im_download_from_cjk_hk_cj, "30,278",
                LIME.DATABASE_CLOUD_IM_CJHK));
        list.add(new ImFamily(LIME.DB_TABLE_CJ, "倉頡", cj, true, false, false));

        // 倉頡五代
        List<CloudVariant> cj5 = new ArrayList<>();
        cj5.add(new CloudVariant(R.string.l3_im_download_from_cj5, "24,004",
                LIME.DATABASE_CLOUD_IM_CJ5));
        list.add(new ImFamily(LIME.DB_TABLE_CJ5, "倉頡五代", cj5, true, false, false));

        // 速倉
        List<CloudVariant> scj = new ArrayList<>();
        scj.add(new CloudVariant(R.string.l3_im_download_from_scj, "74,250",
                LIME.DATABASE_CLOUD_IM_SCJ));
        list.add(new ImFamily(LIME.DB_TABLE_SCJ, "速倉", scj, true, false, false));

        // 英文倉頡
        List<CloudVariant> ecj = new ArrayList<>();
        ecj.add(new CloudVariant(R.string.l3_im_download_from_ecj, "13,119",
                LIME.DATABASE_CLOUD_IM_ECJ));
        ecj.add(new CloudVariant(R.string.l3_im_download_from_cjk_hk_ecj, "27,853",
                LIME.DATABASE_CLOUD_IM_ECJHK));
        list.add(new ImFamily(LIME.DB_TABLE_ECJ, "英文倉頡", ecj, true, false, false));

        // 大易
        List<CloudVariant> dayi = new ArrayList<>();
        dayi.add(new CloudVariant(R.string.setup_load_download_dayiuni, "27,198",
                LIME.DATABASE_CLOUD_IM_DAYIUNI));
        dayi.add(new CloudVariant(R.string.setup_load_download_dayiunip, "117,766",
                LIME.DATABASE_CLOUD_IM_DAYIUNIP));
        dayi.add(new CloudVariant(R.string.l3_im_download_from_dayi, "18,638",
                LIME.DATABASE_CLOUD_IM_DAYI));
        list.add(new ImFamily(LIME.DB_TABLE_DAYI, "大易", dayi, true, false, false));

        // 輕鬆
        List<CloudVariant> ez = new ArrayList<>();
        ez.add(new CloudVariant(R.string.l3_im_download_from_ez, "14,422",
                LIME.DATABASE_CLOUD_IM_EZ));
        list.add(new ImFamily(LIME.DB_TABLE_EZ, "輕鬆", ez, true, false, false));

        // 行列
        List<CloudVariant> array = new ArrayList<>();
        array.add(new CloudVariant(R.string.l3_im_download_from_array, "32,386",
                LIME.DATABASE_CLOUD_IM_ARRAY));
        list.add(new ImFamily(LIME.DB_TABLE_ARRAY, "行列", array, true, false, false));

        // 行列十
        List<CloudVariant> array10 = new ArrayList<>();
        array10.add(new CloudVariant(R.string.l3_im_download_from_array10, "32,120",
                LIME.DATABASE_CLOUD_IM_ARRAY10));
        list.add(new ImFamily(LIME.DB_TABLE_ARRAY10, "行列十", array10, true, false, false));

        // 華象
        List<CloudVariant> hs = new ArrayList<>();
        hs.add(new CloudVariant(R.string.l3_im_download_from_hs, "183,659",
                LIME.DATABASE_CLOUD_IM_HS));
        hs.add(new CloudVariant(R.string.l3_im_download_from_hs_v1, "50,845",
                LIME.DATABASE_CLOUD_IM_HS_V1));
        hs.add(new CloudVariant(R.string.l3_im_download_from_hs_v2, "50,838",
                LIME.DATABASE_CLOUD_IM_HS_V2));
        hs.add(new CloudVariant(R.string.l3_im_download_from_hs_v3, "64,324",
                LIME.DATABASE_CLOUD_IM_HS_V3));
        list.add(new ImFamily(LIME.DB_TABLE_HS, "華象", hs, true, false, false));

        // 五筆
        List<CloudVariant> wb = new ArrayList<>();
        wb.add(new CloudVariant(R.string.l3_im_download_from_wb, "26,378",
                LIME.DATABASE_CLOUD_IM_WB));
        list.add(new ImFamily(LIME.DB_TABLE_WB, "五筆", wb, true, false, false));

        // 拼音
        List<CloudVariant> pinyin = new ArrayList<>();
        pinyin.add(new CloudVariant(R.string.l3_im_download_from_pinyin_big5, "34,753",
                LIME.DATABASE_CLOUD_IM_PINYIN));
        list.add(new ImFamily(LIME.DB_TABLE_PINYIN, "拼音", pinyin, true, false, false));

        // 自建 (CUSTOM) — no restore switch, no cloud buttons
        list.add(new ImFamily(LIME.DB_TABLE_CUSTOM, "自建", new ArrayList<>(), false, false, true));

        // 聯想詞庫 (RELATED) — no restore switch, no cloud buttons, no txt import
        list.add(new ImFamily(LIME.DB_TABLE_RELATED, "聯想詞庫", new ArrayList<>(), false, true, false));

        return list;
    }

    // -------- Adapter --------

    private class ImFamilyAdapter extends RecyclerView.Adapter<ImFamilyViewHolder> {

        private final List<ImFamily> families;
        private final boolean[] expanded;

        ImFamilyAdapter(List<ImFamily> families) {
            this.families = families;
            this.expanded = new boolean[families.size()];
        }

        @NonNull
        @Override
        public ImFamilyViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
            View v = LayoutInflater.from(parent.getContext())
                    .inflate(R.layout.item_im_family_card, parent, false);
            return new ImFamilyViewHolder(v);
        }

        @Override
        public void onBindViewHolder(@NonNull ImFamilyViewHolder holder, int position) {
            ImFamily family = families.get(position);
            holder.bind(family, expanded[position], () -> {
                int pos = holder.getLayoutPosition();
                if (pos == RecyclerView.NO_POSITION) return;
                expanded[pos] = !expanded[pos];
                notifyItemChanged(pos);
            });
        }

        @Override
        public int getItemCount() {
            return families.size();
        }
    }

    // -------- ViewHolder --------

    private class ImFamilyViewHolder extends RecyclerView.ViewHolder {

        final LinearLayout cardHeader;
        final TextView tvTitle;
        final android.widget.ImageView ivChevron;
        final LinearLayout bodyContainer;
        final SwitchMaterial switchRestoreLearning;
        final LinearLayout cloudButtonsContainer;
        final MaterialButton btnImportLimedb;
        final MaterialButton btnImportTxt;
        final MaterialButton btnImportDefaultRelated;

        ImFamilyViewHolder(@NonNull View itemView) {
            super(itemView);
            cardHeader = itemView.findViewById(R.id.card_header);
            tvTitle = itemView.findViewById(R.id.tv_im_title);
            ivChevron = itemView.findViewById(R.id.iv_chevron);
            bodyContainer = itemView.findViewById(R.id.body_container);
            switchRestoreLearning = itemView.findViewById(R.id.switch_restore_learning);
            cloudButtonsContainer = itemView.findViewById(R.id.cloud_buttons_container);
            btnImportLimedb = itemView.findViewById(R.id.btn_import_limedb);
            btnImportTxt = itemView.findViewById(R.id.btn_import_txt);
            btnImportDefaultRelated = itemView.findViewById(R.id.btn_import_default_related);
        }

        void bind(ImFamily family, boolean isExpanded, Runnable toggleExpand) {
            tvTitle.setText(family.displayTitle);

            // Restore switch visibility
            if (family.hasRestoreSwitch) {
                switchRestoreLearning.setVisibility(View.VISIBLE);
                // Restore persisted state without triggering listener
                switchRestoreLearning.setOnCheckedChangeListener(null);
                switchRestoreLearning.setChecked(getRestorePref(family.tableName));
                switchRestoreLearning.setOnCheckedChangeListener((buttonView, isChecked) ->
                        setRestorePref(family.tableName, isChecked));
            } else {
                switchRestoreLearning.setVisibility(View.GONE);
            }

            // Cloud buttons — rebuild each bind to avoid stale listeners
            cloudButtonsContainer.removeAllViews();
            if (!family.cloudVariants.isEmpty()) {
                cloudButtonsContainer.setVisibility(View.VISIBLE);
                for (CloudVariant variant : family.cloudVariants) {
                    MaterialButton btn = new MaterialButton(
                            requireContext(),
                            null,
                            com.google.android.material.R.attr.borderlessButtonStyle);
                    btn.setLayoutParams(new LinearLayout.LayoutParams(
                            LinearLayout.LayoutParams.MATCH_PARENT,
                            LinearLayout.LayoutParams.WRAP_CONTENT));
                    String label = getString(R.string.download_button_with_count,
                            getString(variant.labelResId), variant.count);
                    btn.setText(label);
                    final String url = variant.url;
                    btn.setOnClickListener(v -> {
                        if (setupImController != null) {
                            setupImController.downloadAndImportZippedDb(
                                    family.tableName, url,
                                    switchRestoreLearning.isChecked());
                        }
                    });
                    cloudButtonsContainer.addView(btn);
                }
            } else {
                cloudButtonsContainer.setVisibility(View.GONE);
            }

            // .limedb import button (all families)
            btnImportLimedb.setOnClickListener(v ->
                    launchLimedbPicker(family.tableName, family.isRelated));

            // .cin/.lime import (hidden for RELATED)
            if (family.isRelated) {
                btnImportTxt.setVisibility(View.GONE);
            } else {
                btnImportTxt.setVisibility(View.VISIBLE);
                btnImportTxt.setOnClickListener(v -> launchTxtPicker(family.tableName));
            }

            // Default related button (visible only for RELATED)
            if (family.isRelated) {
                btnImportDefaultRelated.setVisibility(View.VISIBLE);
                btnImportDefaultRelated.setOnClickListener(v -> showDefaultRelatedConfirmDialog());
            } else {
                btnImportDefaultRelated.setVisibility(View.GONE);
            }

            // Expand/collapse
            bodyContainer.setVisibility(isExpanded ? View.VISIBLE : View.GONE);
            ivChevron.clearAnimation();
            ivChevron.setRotation(isExpanded ? 180f : 0f);

            cardHeader.setOnClickListener(v -> {
                float toDeg = isExpanded ? 0f : 180f;
                ivChevron.animate().rotation(toDeg).setDuration(200).start();
                toggleExpand.run();
            });
        }
    }

    private void showDefaultRelatedConfirmDialog() {
        if (activity == null) return;
        new AlertDialog.Builder(activity)
                .setMessage(R.string.setup_im_import_related_default_confirm)
                .setPositiveButton(R.string.dialog_confirm, (dialog, which) -> {
                    if (setupImController != null) {
                        setupImController.importDbDefaultRelated();
                    }
                })
                .setNegativeButton(R.string.dialog_cancel, (dialog, which) -> dialog.dismiss())
                .show();
    }
}

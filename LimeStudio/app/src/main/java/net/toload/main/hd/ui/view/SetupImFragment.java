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
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;
import android.os.Looper;

import androidx.annotation.NonNull;
import androidx.core.content.pm.PackageInfoCompat;
import androidx.fragment.app.Fragment;
import androidx.fragment.app.FragmentTransaction;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;


import net.toload.main.hd.data.ImConfig;
import net.toload.main.hd.ui.LIMESettings;
import net.toload.main.hd.global.LIME;
import net.toload.main.hd.R;
import net.toload.main.hd.global.LIMEPreferenceManager;
import net.toload.main.hd.global.LIMEUtilities;
import net.toload.main.hd.ui.controller.SetupImController;
import net.toload.main.hd.ui.dialog.ImportDialog;
import net.toload.main.hd.ui.dialog.SetupImLoadDialog;

import java.io.File;
import java.util.HashMap;
import java.util.List;
import java.util.Map;


/**
 * A placeholder fragment containing a simple rootView.
 */
public class SetupImFragment extends Fragment implements SetupImView {


    // IM Log Tag
    private final String TAG = "SetupImFragment";

    // Debug Flag
    private final boolean DEBUG = false;

    // BroadcastReceiver to listen for IME changes
    private BroadcastReceiver imeChangeReceiver = null;

    //Activate LIME IM

    Button btnSetupImSystemSettings;
    Button btnSetupImSystemIMPicker;


    private View rootView;
    private SetupImController setupImController;
    private Activity activity;
    private LIMEPreferenceManager mLIMEPref;

    List<ImConfig> imlist;

    TextView txtVersion;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
    }

    @Override
    public void onPause() {
        super.onPause();

        // Update IM pick up list items
        if(imlist != null && !imlist.isEmpty()){
            mLIMEPref.syncIMActivatedState(imlist);
        }

        // Unregister BroadcastReceiver to prevent memory leaks
        unregisterImeChangeReceiver();
    }

    /**
     * The fragment argument representing the section number for this
     * fragment.
     */
    private static final String ARG_SECTION_NUMBER = "section_number";

    /**
     * Returns a new instance of this fragment for the given section
     * number.
     */
    public static SetupImFragment newInstance(int sectionNumber) {
        SetupImFragment frg = new SetupImFragment();
        Bundle args = new Bundle();
                args.putInt(ARG_SECTION_NUMBER, sectionNumber);
        frg.setArguments(args);
        return frg;
    }


    @Override
    public void onResume() {

        super.onResume();

        // Register BroadcastReceiver to listen for IME changes
        // This detects when user enables/disables/switches IME in system settings
        registerImeChangeReceiver();

        // Also refresh immediately in case no broadcast is sent
        if (rootView != null) {
            new android.os.Handler(Looper.getMainLooper()).postDelayed(() -> {
                if (isAdded() && rootView != null) {
                    Log.i(TAG, "onResume() - refreshing button state");
                    refreshButtonState();
                }
            }, 500); // 500ms delay ensures system processes the IME change
        }

    }

    /**
     * Register receiver to listen for IME changes
     * Detects when user enables/disables LIME or switches to another IME
     */
    private void registerImeChangeReceiver() {
        if (imeChangeReceiver != null) {
            return; // Already registered
        }

        imeChangeReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                if (intent.getAction() != null && 
                    (intent.getAction().equals("android.intent.action.INPUT_METHOD_CHANGED") ||
                     intent.getAction().equals("android.settings.INPUT_METHOD_SETTINGS"))) {
                    
                    Log.i(TAG, "IME change detected via broadcast - refreshing UI");
                    if (rootView != null && isAdded()) {
                        refreshButtonState();
                    }
                }
            }
        };

        Context context = requireActivity();
        IntentFilter filter = new IntentFilter();
        filter.addAction("android.intent.action.INPUT_METHOD_CHANGED");
        
        // Register receiver for API compatibility
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(imeChangeReceiver, filter, Context.RECEIVER_EXPORTED);
        } else {
            context.registerReceiver(imeChangeReceiver, filter);
        }
    }

    /**
     * Unregister the IME change receiver
     */
    private void unregisterImeChangeReceiver() {
        if (imeChangeReceiver != null) {
            try {
                requireActivity().unregisterReceiver(imeChangeReceiver);
                Log.i(TAG, "IME change receiver unregistered");
            } catch (IllegalArgumentException e) {
                Log.w(TAG, "IME change receiver was not registered: " + e.getMessage());
            }
            imeChangeReceiver = null;
        }
    }




    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container,
                             Bundle savedInstanceState) {

        activity = getActivity();

        if (activity instanceof LIMESettings) {
            setupImController = ((LIMESettings) activity).getSetupImController();
            if (setupImController != null) {
                setupImController.setSetupImView(this);
            } else {
                Log.w(TAG, "SetupImController is null; UI operations may fail");
            }
        } else {
            Log.w(TAG, "Activity is not LIMESettings; SetupImController unavailable");
        }

        assert activity != null;
        mLIMEPref = new LIMEPreferenceManager(activity);

        rootView = inflater.inflate(R.layout.fragment_setup_im, container, false);


        btnSetupImSystemSettings = rootView.findViewById(R.id.btnSetupImSystemSetting);
        btnSetupImSystemIMPicker = rootView.findViewById(R.id.btnSetupImSystemIMPicker);



        PackageInfo pInfo;
        try {
            pInfo = requireActivity().getPackageManager().getPackageInfo(requireActivity().getPackageName(), 0);
            long versionCode = PackageInfoCompat.getLongVersionCode(pInfo);
            txtVersion = rootView.findViewById(R.id.txtVersion);
            txtVersion.setText(getString(R.string.version_format, pInfo.versionName, versionCode));
        } catch (PackageManager.NameNotFoundException e) {
            Log.e(TAG, "Error in operation", e);
        }

        return rootView;
    }
    @Override
    public void refreshButtonState(){
        // Safety checks: ensure fragment is attached and views are ready
        if (!isAdded() || activity == null || rootView == null) {
            if (DEBUG) Log.w(TAG, "refreshButtonState skipped: fragment not ready");
            return;
        }

        if (setupImController != null) {
            try {
                // Get IM list for other operations
                imlist = setupImController.getImConfigList();
                // Update IM pick up list items
                mLIMEPref.syncIMActivatedState(imlist);

                if(LIMEUtilities.isLIMEEnabled(requireActivity().getApplicationContext())){  //LIME is activated in system
                    btnSetupImSystemSettings.setVisibility(View.GONE);
                    rootView.findViewById(R.id.setup_im_system_settings_description).setVisibility(View.GONE);
                    rootView.findViewById(R.id.SetupImList).setVisibility(View.VISIBLE);
                    //LIME is activated, also the active Keyboard
                    if(LIMEUtilities.isLIMEActive(requireActivity().getApplicationContext())) {
                        btnSetupImSystemIMPicker.setVisibility(View.GONE);
                        rootView.findViewById(R.id.Setup_Wizard).setVisibility(View.GONE);

                    }
                    //LIME is activated, but not active keyboard
                    else
                    {

                        btnSetupImSystemIMPicker.setVisibility(View.VISIBLE);
                        rootView.findViewById(R.id.setup_im_system_impicker_description).setVisibility(View.VISIBLE);

                    }
                }else {
                    btnSetupImSystemSettings.setVisibility(View.VISIBLE);
                    rootView.findViewById(R.id.setup_im_system_settings_description).setVisibility(View.VISIBLE);
                    btnSetupImSystemIMPicker.setVisibility(View.GONE);
                    rootView.findViewById(R.id.setup_im_system_impicker_description).setVisibility(View.GONE);
                    rootView.findViewById(R.id.SetupImList).setVisibility(View.GONE);
                }


                btnSetupImSystemSettings.setOnClickListener(v -> {
                    Log.i(TAG, "Opening IME settings to enable LimeIME");
                    LIMEUtilities.showInputMethodSettingsPage(requireActivity().getApplicationContext());
                });

                btnSetupImSystemIMPicker.setOnClickListener(v -> {
                    Log.i(TAG, "Opening IME picker to select LimeIME");
                    LIMEUtilities.showInputMethodPicker(requireActivity().getApplicationContext());
                });




            } catch (Exception e) {
                Log.e(TAG, "Error in operation", e);
            }
        }

    }

    @Override
    public void onAttach(@NonNull Context context) {
        super.onAttach(context);
    }

    public void showToastMessage(String msg, int length) {
        runOnUi(() -> {
            Toast toast = Toast.makeText(activity, msg, length);
            toast.show();
        });
    }

    public void restoreCustomButtonText() {
        // Button removed; no-op kept for SetupImLoadDialog compatibility
    }

    public void clearTable(String tableName, boolean restoreUserRecords){
        if (setupImController != null) {
            setupImController.clearTable(tableName, restoreUserRecords);
        }
    }



    /**
     * Returns the number of records in a table. Used by dialogs/handlers.
     */
    public int countRecords(String tabelName) {
        if (setupImController != null) {
            return setupImController.countRecords(tabelName);
        }
        return 0;
    }



    /**
     * Imports a text mapping file (.lime, .cin, or delimited text) into the specified database table.
     *
     * <p>This method imports text mapping files into the database table. It delegates to
     * {@link DBServer#importTxtTable(String, String, LIMEProgressListener)} to perform the actual
     * import operation. After import completes, it optionally restores user-learned records from
     * a backup table if requested.
     *
     * <p>The method performs the following operations:
     * <ul>
     *   <li>Shows progress indicator with custom message</li>
     *   <li>Delegates to DBServer.importTxtTable() for the actual import</li>
     *   <li>Updates progress during import via LIMEProgressListener callbacks</li>
     *   <li>Optionally restores user-learned records from backup table after import</li>
     *   <li>Cancels progress indicator when complete</li>
     * </ul>
     *
     * <p>This method is called from SetupImLoadDialog when a user selects a text file to import.
     *
     * @param sourceFile The text file to import (.lime, .cin, or delimited text)
     * @param tableName The IM type (table name) to import into (e.g., "custom", "phonetic")
     * @param restoreUserRecords If true, restores user-learned records from backup table after import
     */
    public void importTxtTable(File sourceFile, String tableName, boolean restoreUserRecords) {
        setupImController.importTxtTable(sourceFile, tableName, restoreUserRecords);

    }

    /**
     * Imports the default related database from raw resources.
     */
    public void importZippedDbDefaultRelated() {
        if (setupImController != null) {
            setupImController.importDbDefaultRelated();
        }
    }

    /**
     * Imports a compressed related database file (.limedb).
     */
    public void importZippedDbRelated(File unit) {
        if (setupImController != null) {
            setupImController.importZippedDbRelated(unit);
        }
    }

    /**
     * Imports a compressed database file (.limedb) into the specified IM table.
     */
    public void importZippedDb(File unit, String tableName, boolean restoreUserRecords) {
        if (setupImController != null) {
            setupImController.importZippedDb(unit, tableName, restoreUserRecords);
        }
    }

    /**
     * Downloads and loads an IM database from the cloud.
     *
     * <p>This method checks network availability, then delegates the download
     * and import flow to the controller. After import completes, it optionally
     * restores user-learned records from a backup table if requested.
     *
     *
     * @param tableName The IM table to import into (e.g., "custom", "phonetic")
     * @param imTableVariant One of available table variants for a specific IM
     * @param restoreLearning Whether to restore user-learned records after import
     */
    public void downloadAndImportZippedDb(String tableName, String imTableVariant, boolean restoreLearning) {
        if (setupImController != null) {
            setupImController.downloadAndImportZippedDb(tableName, getUrlForImTableVariant(imTableVariant) , restoreLearning);
        }
    }




    @Override
    public void showImportDialog() {
        FragmentTransaction ft = getParentFragmentManager().beginTransaction();
        // Pass empty import text when shown from the setup UI
        ImportDialog dialog = ImportDialog.newInstance("");
        dialog.show(ft, "importdialog");
    }





    // Utility: run UI updates on the main thread safely
    private void runOnUi(Runnable r) {
        if (activity == null || r == null) return;
        if (Looper.myLooper() == Looper.getMainLooper()) {
            r.run();
        } else {
            activity.runOnUiThread(r);
        }
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (setupImController != null) {
            setupImController.setSetupImView(null);
        }
    }

    @Override
    public void onError(String message) {
        Log.e(TAG, message);
        showToastMessage(message, Toast.LENGTH_LONG);
    }


    private String getUrlForImTableVariant(String imTableVariant) {
        Map<String, String> imTableVariantToUrl = new HashMap<>();
        imTableVariantToUrl.put(LIME.IM_ARRAY, LIME.DATABASE_CLOUD_IM_ARRAY);
        imTableVariantToUrl.put(LIME.IM_ARRAY10, LIME.DATABASE_CLOUD_IM_ARRAY10);
        imTableVariantToUrl.put(LIME.IM_CJ_BIG5, LIME.DATABASE_CLOUD_IM_CJ_BIG5);
        imTableVariantToUrl.put(LIME.IM_CJ, LIME.DATABASE_CLOUD_IM_CJ);
        imTableVariantToUrl.put(LIME.IM_CJHK, LIME.DATABASE_CLOUD_IM_CJHK);
        imTableVariantToUrl.put(LIME.IM_CJ5, LIME.DATABASE_CLOUD_IM_CJ5);
        imTableVariantToUrl.put(LIME.IM_DAYI, LIME.DATABASE_CLOUD_IM_DAYI);
        imTableVariantToUrl.put(LIME.IM_DAYIUNI, LIME.DATABASE_CLOUD_IM_DAYIUNI);
        imTableVariantToUrl.put(LIME.IM_DAYIUNIP, LIME.DATABASE_CLOUD_IM_DAYIUNIP);
        imTableVariantToUrl.put(LIME.IM_ECJ, LIME.DATABASE_CLOUD_IM_ECJ);
        imTableVariantToUrl.put(LIME.IM_ECJHK, LIME.DATABASE_CLOUD_IM_ECJHK);
        imTableVariantToUrl.put(LIME.IM_EZ, LIME.DATABASE_CLOUD_IM_EZ);
        imTableVariantToUrl.put(LIME.IM_PHONETIC_BIG5, LIME.DATABASE_CLOUD_IM_PHONETIC_BIG5);
        imTableVariantToUrl.put(LIME.IM_PHONETIC_ADV_BIG5, LIME.DATABASE_CLOUD_IM_PHONETICCOMPLETE_BIG5);
        imTableVariantToUrl.put(LIME.IM_PHONETIC, LIME.DATABASE_CLOUD_IM_PHONETIC);
        imTableVariantToUrl.put(LIME.IM_PHONETIC_ADV, LIME.DATABASE_CLOUD_IM_PHONETICCOMPLETE);
        imTableVariantToUrl.put(LIME.IM_PINYIN, LIME.DATABASE_CLOUD_IM_PINYIN);
        imTableVariantToUrl.put(LIME.IM_PINYINGB, LIME.DATABASE_CLOUD_IM_PINYINGB);
        imTableVariantToUrl.put(LIME.IM_SCJ, LIME.DATABASE_CLOUD_IM_SCJ);
        imTableVariantToUrl.put(LIME.IM_WB, LIME.DATABASE_CLOUD_IM_WB);
        imTableVariantToUrl.put(LIME.IM_HS, LIME.DATABASE_CLOUD_IM_HS);
        imTableVariantToUrl.put(LIME.IM_HS_V1, LIME.DATABASE_CLOUD_IM_HS_V1);
        imTableVariantToUrl.put(LIME.IM_HS_V2, LIME.DATABASE_CLOUD_IM_HS_V2);
        imTableVariantToUrl.put(LIME.IM_HS_V3, LIME.DATABASE_CLOUD_IM_HS_V3);
        return imTableVariantToUrl.get(imTableVariant);
    }


}

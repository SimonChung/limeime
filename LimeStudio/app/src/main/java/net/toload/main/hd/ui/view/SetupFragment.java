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
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;
import androidx.core.content.pm.PackageInfoCompat;
import androidx.fragment.app.Fragment;

import com.google.android.material.button.MaterialButton;
import com.google.android.material.card.MaterialCardView;

import net.toload.main.hd.R;
import net.toload.main.hd.global.LIMEUtilities;

/**
 * Activation-guide and About card fragment for the 設定 (Setup) tab.
 *
 * <p>Displays current IME activation status, step-by-step setup instructions,
 * buttons to open system IME settings / picker, and an About card with version,
 * license, and source-code link.
 */
public class SetupFragment extends Fragment {

    private static final String TAG = "SetupFragment";

    private Activity activity;
    private BroadcastReceiver imeChangeReceiver;

    private MaterialCardView statusCard;
    private TextView statusText;
    private MaterialButton btnSystemSettings;
    private MaterialButton btnImePicker;

    public static SetupFragment newInstance() {
        return new SetupFragment();
    }

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container,
                             Bundle savedInstanceState) {
        activity = getActivity();
        View rootView = inflater.inflate(R.layout.fragment_setup, container, false);

        statusCard = rootView.findViewById(R.id.statusCard);
        statusText = rootView.findViewById(R.id.statusText);
        btnSystemSettings = rootView.findViewById(R.id.btnSetupImSystemSetting);
        btnImePicker = rootView.findViewById(R.id.btnSetupImSystemIMPicker);

        btnSystemSettings.setOnClickListener(v ->
                LIMEUtilities.showInputMethodSettingsPage(requireActivity().getApplicationContext()));
        btnImePicker.setOnClickListener(v ->
                LIMEUtilities.showInputMethodPicker(requireActivity().getApplicationContext()));

        // Version in about card
        try {
            PackageInfo pInfo = requireActivity().getPackageManager()
                    .getPackageInfo(requireActivity().getPackageName(), 0);
            long code = PackageInfoCompat.getLongVersionCode(pInfo);
            ((TextView) rootView.findViewById(R.id.txtVersion))
                    .setText(getString(R.string.version_format, pInfo.versionName, code));
        } catch (Exception e) {
            Log.w(TAG, "Could not read version", e);
        }

        // GitHub link tap
        TextView txtGithub = rootView.findViewById(R.id.txtGithubUrl);
        if (txtGithub != null) {
            txtGithub.setOnClickListener(v -> {
                Intent intent = new Intent(Intent.ACTION_VIEW,
                        Uri.parse(getString(R.string.url_github_limeime)));
                startActivity(intent);
            });
        }

        return rootView;
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        activity = null;
    }

    @Override
    public void onResume() {
        super.onResume();
        registerImeReceiver();
        refreshStatus();
    }

    @Override
    public void onPause() {
        super.onPause();
        unregisterImeReceiver();
    }

    private void refreshStatus() {
        if (!isAdded() || activity == null) return;
        Context ctx = activity.getApplicationContext();
        boolean enabled = LIMEUtilities.isLIMEEnabled(ctx);
        boolean active = LIMEUtilities.isLIMEActive(ctx);

        if (enabled && active) {
            statusCard.setCardBackgroundColor(ContextCompat.getColor(activity, R.color.setup_status_green));
            statusText.setText(R.string.setup_status_active);
            btnSystemSettings.setVisibility(View.GONE);
            btnImePicker.setVisibility(View.GONE);
        } else if (enabled) {
            statusCard.setCardBackgroundColor(ContextCompat.getColor(activity, R.color.setup_status_yellow));
            statusText.setText(R.string.setup_status_enabled_not_active);
            btnSystemSettings.setVisibility(View.GONE);
            btnImePicker.setVisibility(View.VISIBLE);
        } else {
            statusCard.setCardBackgroundColor(ContextCompat.getColor(activity, R.color.setup_status_red));
            statusText.setText(R.string.setup_status_not_enabled);
            btnSystemSettings.setVisibility(View.VISIBLE);
            btnImePicker.setVisibility(View.GONE);
        }
    }

    private void registerImeReceiver() {
        if (imeChangeReceiver != null || activity == null) return;
        imeChangeReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                refreshStatus();
            }
        };
        IntentFilter filter = new IntentFilter("android.intent.action.INPUT_METHOD_CHANGED");
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.registerReceiver(imeChangeReceiver, filter, Context.RECEIVER_EXPORTED);
        } else {
            activity.registerReceiver(imeChangeReceiver, filter);
        }
    }

    private void unregisterImeReceiver() {
        if (imeChangeReceiver != null && activity != null) {
            try {
                activity.unregisterReceiver(imeChangeReceiver);
            } catch (IllegalArgumentException ignored) {
            }
            imeChangeReceiver = null;
        }
    }
}

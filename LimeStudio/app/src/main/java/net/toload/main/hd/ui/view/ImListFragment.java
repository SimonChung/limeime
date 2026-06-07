package net.toload.main.hd.ui.view;

import android.app.Activity;
import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.lifecycle.ViewModelProvider;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.google.android.material.appbar.MaterialToolbar;
import com.google.android.material.floatingactionbutton.FloatingActionButton;
import com.google.android.material.switchmaterial.SwitchMaterial;

import net.toload.main.hd.R;
import net.toload.main.hd.data.ImConfig;
import net.toload.main.hd.global.LIME;
import net.toload.main.hd.ui.LIMESettings;
import net.toload.main.hd.ui.controller.ManageImController;
import net.toload.main.hd.ui.viewmodel.ImNavigationViewModel;

import java.util.ArrayList;
import java.util.List;

/**
 * Fragment showing the list of available IMs with enable/disable toggles.
 * Hosted inside TwoPaneHostFragment's list pane.
 */
public class ImListFragment extends Fragment {

    private static final String TAG = "ImListFragment";

    private Activity activity;
    private ManageImController manageImController;
    private ImNavigationViewModel vm;
    private ImRowAdapter adapter;

    public static ImListFragment newInstance() {
        return new ImListFragment();
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

        // ViewModel is scoped to TwoPaneHostFragment (parent)
        vm = new ViewModelProvider(requireParentFragment()).get(ImNavigationViewModel.class);

        View rootView = inflater.inflate(R.layout.fragment_im_list, container, false);

        FloatingActionButton fab = rootView.findViewById(R.id.fab_install);
        fab.setOnClickListener(v -> vm.showInstall.setValue(true));

        // Push FAB above the activity's BottomNavigationView (fragment container fills full screen)
        View bottomNav = requireActivity().findViewById(R.id.main_bottom_nav);
        if (bottomNav != null) {
            bottomNav.post(() -> {
                int navHeight = bottomNav.getHeight();
                if (navHeight > 0 && fab.getLayoutParams() instanceof ViewGroup.MarginLayoutParams) {
                    ViewGroup.MarginLayoutParams lp = (ViewGroup.MarginLayoutParams) fab.getLayoutParams();
                    lp.bottomMargin = navHeight + (int) (16 * getResources().getDisplayMetrics().density);
                    fab.setLayoutParams(lp);
                }
            });
        }

        RecyclerView recyclerView = rootView.findViewById(R.id.im_list_recycler);
        recyclerView.setLayoutManager(new LinearLayoutManager(requireContext()));
        ScrollableTabHelper.applyToRecyclerView(activity, recyclerView);

        adapter = new ImRowAdapter(new ArrayList<>());
        recyclerView.setAdapter(adapter);

        loadImList();

        return rootView;
    }

    /** Re-query the IM config table and refresh the list. Safe to call from any thread. */
    public void refreshList() {
        loadImList();
    }

    private void loadImList() {
        final ManageImController ctrl = manageImController;
        if (ctrl == null) return;
        final Activity act = activity;

        new Thread(() -> {
            final List<ImConfig> rawList = ctrl.getImConfigFullNameList();
            // Filter out the internal emoji dataset — it is not a user-facing Chinese IM
            final List<ImConfig> list = new ArrayList<>();
            for (ImConfig im : rawList) {
                if (!"emoji".equals(im.getCode())) {
                    list.add(im);
                }
            }
            if (act == null) return;
            act.runOnUiThread(() -> {
                if (!isAdded() || activity == null) return;
                adapter.setData(list);
            });
        }).start();
    }

    @Override
    public void onResume() {
        super.onResume();
        // Refresh the list when returning from IM Detail (e.g., after Remove-IM)
        if (manageImController != null && adapter != null) {
            loadImList();
        }
    }

    @Override
    public void onDestroyView() {
        View root = getView();
        if (root != null) {
            RecyclerView rv = root.findViewById(R.id.im_list_recycler);
            if (rv != null) {
                rv.setAdapter(null);
            }
        }
        super.onDestroyView();
        activity = null;
        manageImController = null;
        vm = null;
        adapter = null;
    }

    /**
     * Returns true if {@code activeImCode} corresponds to an IM that is currently
     * enabled (not disabled) in the in-memory list. Used to decide whether a newly
     * enabled IM should become the active IM. Reads the adapter's in-memory list so
     * it is not subject to the async DB write performed by setImEnabled().
     */
    private boolean isActiveImEnabled(String activeImCode) {
        if (activeImCode == null || adapter == null) return false;
        List<ImConfig> list = adapter.getImList();
        if (list == null) return false;
        for (ImConfig im : list) {
            if (im == null || im.getCode() == null) continue;
            if (activeImCode.equals(im.getCode())) {
                return !im.isDisable();
            }
        }
        return false;
    }

    // -------- Adapter --------

    private class ImRowAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {

        private static final int TYPE_IM = 0;
        private static final int TYPE_RELATED = 1;
        private static final int TYPE_HEADER = 2;

        private List<ImConfig> imList;

        ImRowAdapter(List<ImConfig> imList) {
            this.imList = imList;
        }

        List<ImConfig> getImList() {
            return imList;
        }

        void setData(List<ImConfig> data) {
            this.imList = data != null ? data : new ArrayList<>();
            notifyDataSetChanged();
            View root = getView();
            if (root != null) {
                ScrollableTabHelper.refreshRecyclerViewScrollbar(root.findViewById(R.id.im_list_recycler));
            }
        }

        @Override
        public int getItemCount() {
            // header(installed) + IM rows + header(related) + related row
            return 1 + imList.size() + 1 + 1;
        }

        @Override
        public int getItemViewType(int position) {
            if (position == 0) return TYPE_HEADER; // installed header
            int imEnd = 1 + imList.size();
            if (position < imEnd) return TYPE_IM;
            if (position == imEnd) return TYPE_HEADER; // related header
            return TYPE_RELATED;
        }

        @NonNull
        @Override
        public RecyclerView.ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
            if (viewType == TYPE_HEADER) {
                android.widget.TextView tv = new android.widget.TextView(parent.getContext());
                tv.setPadding(32, 24, 32, 8);
                tv.setTypeface(null, android.graphics.Typeface.BOLD);
                tv.setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, 13);
                tv.setLayoutParams(new android.view.ViewGroup.LayoutParams(
                        android.view.ViewGroup.LayoutParams.MATCH_PARENT,
                        android.view.ViewGroup.LayoutParams.WRAP_CONTENT));
                return new HeaderViewHolder(tv);
            }
            View v = LayoutInflater.from(parent.getContext())
                    .inflate(R.layout.item_im_row, parent, false);
            if (viewType == TYPE_RELATED) {
                return new RelatedViewHolder(v);
            }
            return new ImViewHolder(v);
        }

        @Override
        public void onBindViewHolder(@NonNull RecyclerView.ViewHolder holder, int position) {
            if (holder instanceof HeaderViewHolder) {
                int labelRes = (position == 0) ? R.string.im_list_header_installed : R.string.im_list_header_related;
                ((HeaderViewHolder) holder).bind(labelRes);
            } else if (holder instanceof RelatedViewHolder) {
                ((RelatedViewHolder) holder).bind();
            } else if (holder instanceof ImViewHolder) {
                // position 0 is header, so IM data starts at position 1
                ((ImViewHolder) holder).bind(imList.get(position - 1));
            }
        }
    }

    private class HeaderViewHolder extends RecyclerView.ViewHolder {
        final android.widget.TextView tvHeader;

        HeaderViewHolder(@NonNull android.widget.TextView itemView) {
            super(itemView);
            tvHeader = itemView;
        }

        void bind(int labelRes) {
            tvHeader.setText(labelRes);
            tvHeader.setClickable(false);
        }
    }

    private class ImViewHolder extends RecyclerView.ViewHolder {
        final TextView tvLabel;
        final SwitchMaterial switchEnabled;

        ImViewHolder(@NonNull View itemView) {
            super(itemView);
            tvLabel = itemView.findViewById(R.id.tv_im_label);
            switchEnabled = itemView.findViewById(R.id.switch_im_enabled);
        }

        void bind(ImConfig im) {
            tvLabel.setText(im.getDesc());
            itemView.setAlpha(im.isDisable() ? LIME.HALF_ALPHA_VALUE : 1.0f);

            // Clear listener before setting state to avoid spurious callbacks
            switchEnabled.setOnCheckedChangeListener(null);
            switchEnabled.setChecked(!im.isDisable());
            switchEnabled.setOnCheckedChangeListener((btn, checked) -> {
                im.setDisable(!checked);
                itemView.setAlpha(checked ? 1.0f : LIME.HALF_ALPHA_VALUE);
                ManageImController ctrl = manageImController;
                if (ctrl != null) {
                    ctrl.setImEnabled(im.getId(), checked);
                    net.toload.main.hd.global.LIMEPreferenceManager pref =
                            new net.toload.main.hd.global.LIMEPreferenceManager(requireContext());
                    pref.syncIMActivatedState(ctrl.getImConfigFullNameList());
                    // When enabling an IM, make it the active IM if the currently
                    // persisted active IM is not (or no longer) an enabled one. This
                    // ensures the first IM installed/enabled on a fresh install becomes
                    // active instead of leaving activeIM pointing at a default IM whose
                    // keyboard config is not loaded (which falls back to the English
                    // keyboard). Uses the adapter's in-memory list to stay race-free
                    // against the async DB write in setImEnabled().
                    if (checked && !isActiveImEnabled(pref.getActiveIM())) {
                        pref.setActiveIM(im.getCode());
                    }
                }
            });

            itemView.setOnClickListener(v -> {
                ImNavigationViewModel vmRef = vm;
                if (vmRef != null) {
                    vmRef.selectedIm.setValue(im);
                }
            });
        }
    }

    private class RelatedViewHolder extends RecyclerView.ViewHolder {
        final ImageView ivIcon;
        final TextView tvLabel;
        final SwitchMaterial switchEnabled;

        RelatedViewHolder(@NonNull View itemView) {
            super(itemView);
            ivIcon = itemView.findViewById(R.id.iv_im_icon);
            tvLabel = itemView.findViewById(R.id.tv_im_label);
            switchEnabled = itemView.findViewById(R.id.switch_im_enabled);
        }

        void bind() {
            tvLabel.setText(R.string.im_related_label);
            ivIcon.setImageResource(R.drawable.ic_list_bullet);
            switchEnabled.setVisibility(View.GONE);
            itemView.setAlpha(1.0f);

            itemView.setOnClickListener(v -> {
                Fragment parent = getParentFragment();
                if (parent instanceof TwoPaneHostFragment) {
                    ImConfig synthetic = new ImConfig();
                    synthetic.setId(-1);
                    synthetic.setCode("related");
                    synthetic.setDesc(itemView.getResources().getString(R.string.im_related_heading));
                    ((TwoPaneHostFragment) parent).navigateToDetail(
                            ImDetailFragment.newInstance(synthetic));
                }
            });
        }
    }
}

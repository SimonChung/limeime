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

        MaterialToolbar toolbar = rootView.findViewById(R.id.im_list_toolbar);
        toolbar.inflateMenu(R.menu.im_list_menu);
        toolbar.setOnMenuItemClickListener(item -> {
            if (item.getItemId() == R.id.action_install) {
                vm.showInstall.setValue(true);
                return true;
            }
            return false;
        });

        RecyclerView recyclerView = rootView.findViewById(R.id.im_list_recycler);
        recyclerView.setLayoutManager(new LinearLayoutManager(requireContext()));

        adapter = new ImRowAdapter(new ArrayList<>());
        recyclerView.setAdapter(adapter);

        loadImList();

        return rootView;
    }

    private void loadImList() {
        final ManageImController ctrl = manageImController;
        if (ctrl == null) return;
        final Activity act = activity;

        new Thread(() -> {
            final List<ImConfig> list = ctrl.getImConfigFullNameList();
            if (act == null) return;
            act.runOnUiThread(() -> {
                if (!isAdded() || activity == null) return;
                adapter.setData(list);
            });
        }).start();
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

    // -------- Adapter --------

    private class ImRowAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {

        private static final int TYPE_IM = 0;
        private static final int TYPE_RELATED = 1;

        private List<ImConfig> imList;

        ImRowAdapter(List<ImConfig> imList) {
            this.imList = imList;
        }

        void setData(List<ImConfig> data) {
            this.imList = data != null ? data : new ArrayList<>();
            notifyDataSetChanged();
        }

        @Override
        public int getItemCount() {
            // IM rows + one synthetic footer row for the related/linked phrase table
            return imList.size() + 1;
        }

        @Override
        public int getItemViewType(int position) {
            return position < imList.size() ? TYPE_IM : TYPE_RELATED;
        }

        @NonNull
        @Override
        public RecyclerView.ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
            View v = LayoutInflater.from(parent.getContext())
                    .inflate(R.layout.item_im_row, parent, false);
            if (viewType == TYPE_RELATED) {
                return new RelatedViewHolder(v);
            }
            return new ImViewHolder(v);
        }

        @Override
        public void onBindViewHolder(@NonNull RecyclerView.ViewHolder holder, int position) {
            if (holder instanceof RelatedViewHolder) {
                ((RelatedViewHolder) holder).bind();
            } else if (holder instanceof ImViewHolder) {
                ((ImViewHolder) holder).bind(imList.get(position));
            }
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
                    ((TwoPaneHostFragment) parent).navigateToDetail(
                            ManageRelatedFragment.newInstance(1));
                }
            });
        }
    }
}

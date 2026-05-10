package net.toload.main.hd.ui.view;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.lifecycle.ViewModelProvider;
import androidx.slidingpanelayout.widget.SlidingPaneLayout;

import net.toload.main.hd.R;
import net.toload.main.hd.data.ImConfig;
import net.toload.main.hd.ui.viewmodel.ImNavigationViewModel;

/**
 * Host fragment for the two-pane IM management UI.
 *
 * <p>On wide screens (tablets) both panes are visible side-by-side.
 * On narrow screens (phones) the detail pane slides over the list pane.
 *
 * <p>Child fragments (ImListFragment, ImDetailFragment) scope their ViewModel
 * to this fragment via {@code new ViewModelProvider(requireParentFragment())}.
 */
public class TwoPaneHostFragment extends Fragment {

    public static TwoPaneHostFragment newInstance() {
        return new TwoPaneHostFragment();
    }

    private SlidingPaneLayout slidingPaneLayout;

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container,
                             @Nullable Bundle savedInstanceState) {
        return inflater.inflate(R.layout.fragment_two_pane_im_host, container, false);
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);

        slidingPaneLayout = view.findViewById(R.id.sliding_pane_layout);

        // Place ImListFragment in the list pane only on first create (avoid double-init on config change)
        if (savedInstanceState == null) {
            getChildFragmentManager().beginTransaction()
                    .replace(R.id.im_list_pane, ImListFragment.newInstance())
                    .commit();
        }

        // Observe shared ViewModel scoped to this fragment
        ImNavigationViewModel vm = new ViewModelProvider(this).get(ImNavigationViewModel.class);

        vm.selectedIm.observe(getViewLifecycleOwner(), im -> {
            if (im != null) {
                getChildFragmentManager().beginTransaction()
                        .replace(R.id.im_detail_pane, ImDetailFragment.newInstance(im))
                        .addToBackStack(null)
                        .commit();
                if (!slidingPaneLayout.isOpen()) {
                    slidingPaneLayout.open();
                }
                // Reset to null to prevent re-fire on configuration change re-subscription
                vm.selectedIm.setValue(null);
            }
        });

        vm.showInstall.observe(getViewLifecycleOwner(), show -> {
            if (Boolean.TRUE.equals(show)) {
                getChildFragmentManager().beginTransaction()
                        .replace(R.id.im_detail_pane, ImInstallFragment.newInstance())
                        .addToBackStack(null)
                        .commit();
                if (!slidingPaneLayout.isOpen()) {
                    slidingPaneLayout.open();
                }
                // Reset so the observer does not fire again on re-subscription
                vm.showInstall.setValue(false);
            }
        });
    }

    /**
     * Navigates to a detail screen by replacing the detail pane content.
     * Called by child fragments that need to push deeper screens (e.g. ManageImFragment).
     *
     * @param fragment the fragment to show in the detail pane
     */
    public void navigateToDetail(Fragment fragment) {
        getChildFragmentManager().beginTransaction()
                .replace(R.id.im_detail_pane, fragment)
                .addToBackStack(null)
                .commit();
        if (slidingPaneLayout != null && !slidingPaneLayout.isOpen()) {
            slidingPaneLayout.open();
        }
    }
}

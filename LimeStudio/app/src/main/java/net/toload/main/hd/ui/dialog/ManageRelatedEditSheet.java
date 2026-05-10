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

package net.toload.main.hd.ui.dialog;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.android.material.bottomsheet.BottomSheetDialogFragment;
import com.google.android.material.textfield.TextInputEditText;

import net.toload.main.hd.R;
import net.toload.main.hd.data.Related;
import net.toload.main.hd.ui.view.ManageRelatedFragment;

/**
 * Bottom sheet dialog for editing an existing related phrase entry.
 *
 * <p>Pre-populates fields from the given {@link Related} and delegates
 * update/delete operations to the hosting {@link ManageRelatedFragment}.
 */
public class ManageRelatedEditSheet extends BottomSheetDialogFragment {

    private ManageRelatedFragment hostFragment;
    private Related related;
    private int score;

    public static ManageRelatedEditSheet newInstance() {
        return new ManageRelatedEditSheet();
    }

    public void setFragment(ManageRelatedFragment fragment, Related related) {
        this.hostFragment = fragment;
        this.related = related;
        this.score = related.getBasescore();
    }

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container,
                             @Nullable Bundle savedInstanceState) {
        return inflater.inflate(R.layout.sheet_manage_related_edit, container, false);
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);

        TextInputEditText edtWord = view.findViewById(R.id.edt_word);
        TextView tvScore = view.findViewById(R.id.tv_score);

        if (related != null) {
            edtWord.setText(related.getPword() + related.getCword());
            tvScore.setText(String.valueOf(score));
        }

        view.findViewById(R.id.btn_minus).setOnClickListener(v -> {
            if (score > 0) {
                score--;
                tvScore.setText(String.valueOf(score));
            }
        });
        view.findViewById(R.id.btn_plus).setOnClickListener(v -> {
            score++;
            tvScore.setText(String.valueOf(score));
        });

        view.findViewById(R.id.btn_delete).setOnClickListener(v -> {
            if (hostFragment != null && related != null) {
                hostFragment.removeRelated(related.getIdAsInt());
            }
            dismiss();
        });

        view.findViewById(R.id.btn_save).setOnClickListener(v -> {
            String source = edtWord.getText() != null ? edtWord.getText().toString().trim() : "";
            if (source.length() < 2) {
                Toast.makeText(requireContext(), R.string.update_error, Toast.LENGTH_SHORT).show();
                return;
            }
            String pword = source.substring(0, 1);
            String cword = source.substring(1);
            if (hostFragment != null && related != null) {
                hostFragment.updateRelated(related.getIdAsInt(), pword, cword, score);
            }
            dismiss();
        });
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        hostFragment = null;
        related = null;
    }
}

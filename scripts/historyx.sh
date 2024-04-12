#!/bin/bash

preview_settings() {
	default_window_mode=$(tmux_option_or_fallback "@historyx-window-mode" "off")
	if [[ "$default_window_mode" == "on" ]]; then
		PREVIEW_OPTIONS="-w"
	fi
	default_window_mode=$(tmux_option_or_fallback "@historyx-tree-mode" "off")
	if [[ "$default_window_mode" == "on" ]]; then
		PREVIEW_OPTIONS="-t"
	fi
	preview_location=$(tmux_option_or_fallback "@historyx-preview-location" "top")
	preview_ratio=$(tmux_option_or_fallback "@historyx-preview-ratio" "75%")
	preview_enabled=$(tmux_option_or_fallback "@historyx-preview-enabled" "true")
}

window_settings() {
	window_height=$(tmux_option_or_fallback "@historyx-window-height" "75%")
	window_width=$(tmux_option_or_fallback "@historyx-window-width" "75%")
	layout_mode=$(tmux_option_or_fallback "@historyx-layout" "default")
	prompt_icon=$(tmux_option_or_fallback "@historyx-prompt" " ")
	pointer_icon=$(tmux_option_or_fallback "@historyx-pointer" "▶")
}

handle_args() {
	HEADER="$bind_accept=󰿄  $bind_kill_session=󱂧  $bind_rename_session=󰑕  $bind_configuration_mode=󱃖  $bind_window_mode=   $bind_new_window=󰇘  $bind_back=󰌍  $bind_tree_mode=󰐆   $bind_scroll_up=  $bind_scroll_down= "

	args=(
		--exit-0
		--preview-window="${preview_location},${preview_ratio},,"
		--layout="$layout_mode"
		--pointer=$pointer_icon
		-p "$window_width,$window_height"
		--prompt "$prompt_icon"
		--print-query
		--tac
		--scrollbar '▌▐'
	)

	legacy=$(tmux_option_or_fallback "@historyx-legacy-fzf-support" "off")
	if [[ "${legacy}" == "off" ]]; then
		args+=(--border-label "Select Pane to Clear History")
		args+=(--bind 'focus:transform-preview-label:echo [ {} ]')
	fi

	eval "fzf_opts=($additional_fzf_options)"
}

# Function to list panes and their history sizes, and sort by size
list_panes_history() {
    # Declare an array to hold all lines of output temporarily
    declare -a pane_data

    # Collect information for each pane using process substitution to avoid subshell creation
    while read pane_info
    do
        # Extract the pane_id from pane_info
        pane_id=$(echo "$pane_info" | awk '{print $NF}') # Assuming pane_id is the last field

        # Capture the pane's history
        history=$(tmux capture-pane -p -t "$pane_id" -S -)

        # Calculate the size of the history in bytes
        size=$(echo "$history" | wc -c | awk '{print $1}') # Ensure we only get the number

        # Append pane info and size to the array
        pane_data+=("$pane_info $size")
    done < <(tmux list-panes -a -F '#{pane_id} #{session_name}:#{window_name}')

    # Sort pane data by size in descending order and handle right alignment
    # Calculate maximum size for formatting
    max_size_length=$(printf "%s\n" "${pane_data[@]}" | awk '{print $NF}' | awk '{ if (length($1) > max) max = length($1) } END {print max}')

    for line in "${pane_data[@]}"
    do
        pane_details=$(echo "$line" | awk '{$NF=""; print $0}') # remove last field (size)

        size=$(echo "$line" | awk '{print $NF}') # get last field (size)

        # Correct format string in printf
        format="%s %${max_size_length}s bytes\n"
        printf "$format" "$pane_details" "$size"
    done | sort -k3 -n
}

# list_panes_history

preview_settings
window_settings
handle_args

# Use fzf-tmux to select a pane from the list

selected_pane=$(list_panes_history | fzf-tmux "${fzf_opts[@]}" "${args[@]}" --reverse )
# selected_pane=$(list_panes_history | fzf-tmux --height 40% --reverse --prompt='Select Pane to Clear History: ')

# Extract the pane ID from the selection. Assuming pane_id is the first field
pane_id=$(echo "$selected_pane" | awk '{print $1}' | tr -d '[:space:]')

# Clear the history of the selected pane
if [ -n "$pane_id" ]; then
    tmux clear-history -t "$pane_id"
    echo "History cleared for pane $pane_id."
else
    echo "No pane selected."
fi


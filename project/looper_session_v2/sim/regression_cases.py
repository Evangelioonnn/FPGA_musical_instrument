"""The exact mandatory test matrix for this refinement, shared by runner/collector."""
CORE=[(n,[]) for n in ['looper_clock_tb','looper_transport_tb','looper_event_store_tb',
 'looper_auto_close_tb','looper_track_layout_tb','looper_boundary_tb','looper_store_capacity_tb',
 'looper_event_router_tb','looper_event_path_tb','looper_drum_engine_tb','looper_patch_tb',
 'looper_pitch32_tb','looper_controls_tb','looper_top_tb','looper_mix_tb','metronome_control_tb','looper_full_load_tb',
 'record_merge_tb','sine_compact_tb','expression_bank_tb','expression_store_router_tb','expression_roundtrip_tb','expression_empty_tb',
 'custom_service_bound_tb','refinement_link_tb','refinement_link_reset_tb','arrangement_stress_tb']]
CORE += [('looper_store_capacity_tb',['SERIAL=1']),('looper_pitch32_tb',['ALL_CUSTOM=1']),('metronome_accuracy_tb',[]),
 ('metronome_accuracy_tb',['CADENCE=1040','SWEEP=0']),('looper_v2_equivalence_tb',[]),
 ('looper_custom_bound_tb',[]),('looper_custom_bound_tb',['N=32','FULL=0']),
 ('looper_custom_bound_tb',['N=32','FULL=1'])]
UNIT=[('expression_capture_tb',[]),('fader_mode_tb',[]),('looper_keys25_tb',[]),
 ('mcp3208_reader_tb',[]),('mcp3208_reader_tb',['HALF=50','SCAN=50000'])]
PREVIEWS=[('looper_preview_tb',[]),('arrangement_preview_tb',[])]

CORE += [(n,[]) for n in ['session_controls_tb','session_ui_tb','session_unpacker_tb','session_command_tb','session_link_tb','session_link_reset_tb','drum_revision_tb']]

CORE += [('drum_capacity_tb',[])]

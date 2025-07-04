-- 1. TABEL UNTUK MENCATAT SEMUA EVENT DARI SENSOR
CREATE TABLE public.sensor_events (
    id TEXT PRIMARY KEY NOT NULL, -- Format: device_id + epoch. Contoh: garasi_01_1672531200
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    device_id TEXT NOT NULL,
    event_timestamp TIMESTAMPTZ NOT NULL, -- Waktu asli saat event terjadi (dari RTC)
    event_type TEXT NOT NULL, -- Contoh: 'GERAKAN' atau 'GETARAN'
    location_name TEXT,
    image_ref TEXT -- URL publik ke gambar di Supabase Storage
);
COMMENT ON TABLE public.sensor_events IS 'Mencatat setiap event yang terdeteksi oleh sensor.';

-- 2. TABEL UNTUK MEMANTAU STATUS PERANGKAT DAN JADWAL SLEEP
CREATE TABLE public.device_status (
    device_id TEXT PRIMARY KEY NOT NULL, -- Contoh: 'garasi_01'
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    is_online BOOLEAN DEFAULT false,
    last_status_update TIMESTAMPTZ,
    schedule_duration_microseconds BIGINT DEFAULT 0, -- Durasi sleep dalam mikrodetik
    setter_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL -- Foreign Key ke tabel pengguna
);
COMMENT ON TABLE public.device_status IS 'Memantau status online/offline dan jadwal deep sleep perangkat.';

-- Tambahkan trigger untuk otomatis memperbarui kolom 'updated_at'
create extension if not exists moddatetime schema extensions;

create trigger handle_updated_at before update on public.device_status
  for each row execute procedure extensions.moddatetime (updated_at);

create trigger handle_updated_at_events before update on public.sensor_events
  for each row execute procedure extensions.moddatetime (created_at);

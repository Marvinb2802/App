export type Athlete = {
  id: number;
  firstname: string | null;
  lastname: string | null;
  profile: string | null;
  city: string | null;
  country: string | null;
  sex: string | null;
  weight_kg: number | null;
  ftp: number | null;
  max_hr: number | null;
  rest_hr: number | null;
  threshold_hr: number | null;
  /** Schwellentempo in m/s */
  threshold_pace: number | null;
  goal: string | null;
  created_at: string;
  updated_at: string;
};

export type Activity = {
  id: number;
  athlete_id: number;
  name: string | null;
  sport_type: string | null;
  start_date: string;
  start_date_local: string | null;
  distance: number | null;
  moving_time: number | null;
  elapsed_time: number | null;
  total_elevation_gain: number | null;
  average_speed: number | null;
  max_speed: number | null;
  average_heartrate: number | null;
  max_heartrate: number | null;
  average_watts: number | null;
  weighted_average_watts: number | null;
  kilojoules: number | null;
  average_cadence: number | null;
  suffer_score: number | null;
  has_heartrate: number;
  trainer: number;
  synced_at: string;
};

export type StoredTokens = {
  athlete_id: number;
  access_token: string;
  refresh_token: string;
  /** Unix-Sekunden */
  expires_at: number;
  scope: string | null;
};

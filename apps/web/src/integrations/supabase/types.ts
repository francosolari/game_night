export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.4"
  }
  public: {
    Tables: {
      blocked_users: {
        Row: {
          blocked_id: string | null
          blocked_phone: string | null
          blocker_id: string
          created_at: string | null
          id: string
          reason: string | null
        }
        Insert: {
          blocked_id?: string | null
          blocked_phone?: string | null
          blocker_id: string
          created_at?: string | null
          id?: string
          reason?: string | null
        }
        Update: {
          blocked_id?: string | null
          blocked_phone?: string | null
          blocker_id?: string
          created_at?: string | null
          id?: string
          reason?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "blocked_users_blocked_id_fkey"
            columns: ["blocked_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "blocked_users_blocker_id_fkey"
            columns: ["blocker_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      consent_log: {
        Row: {
          consent_type: string
          created_at: string | null
          granted: boolean
          id: string
          ip_address: string | null
          user_agent: string | null
          user_id: string
        }
        Insert: {
          consent_type: string
          created_at?: string | null
          granted: boolean
          id?: string
          ip_address?: string | null
          user_agent?: string | null
          user_id: string
        }
        Update: {
          consent_type?: string
          created_at?: string | null
          granted?: boolean
          id?: string
          ip_address?: string | null
          user_agent?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "consent_log_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      event_games: {
        Row: {
          event_id: string
          game_id: string
          id: string
          is_primary: boolean | null
          sort_order: number | null
        }
        Insert: {
          event_id: string
          game_id: string
          id?: string
          is_primary?: boolean | null
          sort_order?: number | null
        }
        Update: {
          event_id?: string
          game_id?: string
          id?: string
          is_primary?: boolean | null
          sort_order?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "event_games_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "event_games_game_id_fkey"
            columns: ["game_id"]
            isOneToOne: false
            referencedRelation: "games"
            referencedColumns: ["id"]
          },
        ]
      }
      events: {
        Row: {
          allow_time_suggestions: boolean | null
          confirmed_time_option_id: string | null
          cover_image_url: string | null
          created_at: string | null
          description: string | null
          host_id: string
          id: string
          invite_strategy: Json
          location: string | null
          location_address: string | null
          max_players: number | null
          min_players: number
          status: string
          title: string
          updated_at: string | null
        }
        Insert: {
          allow_time_suggestions?: boolean | null
          confirmed_time_option_id?: string | null
          cover_image_url?: string | null
          created_at?: string | null
          description?: string | null
          host_id: string
          id?: string
          invite_strategy?: Json
          location?: string | null
          location_address?: string | null
          max_players?: number | null
          min_players?: number
          status?: string
          title: string
          updated_at?: string | null
        }
        Update: {
          allow_time_suggestions?: boolean | null
          confirmed_time_option_id?: string | null
          cover_image_url?: string | null
          created_at?: string | null
          description?: string | null
          host_id?: string
          id?: string
          invite_strategy?: Json
          location?: string | null
          location_address?: string | null
          max_players?: number | null
          min_players?: number
          status?: string
          title?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "events_host_id_fkey"
            columns: ["host_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fk_confirmed_time"
            columns: ["confirmed_time_option_id"]
            isOneToOne: false
            referencedRelation: "time_options"
            referencedColumns: ["id"]
          },
        ]
      }
      game_categories: {
        Row: {
          created_at: string | null
          icon: string | null
          id: string
          is_default: boolean | null
          name: string
          sort_order: number | null
          user_id: string
        }
        Insert: {
          created_at?: string | null
          icon?: string | null
          id?: string
          is_default?: boolean | null
          name: string
          sort_order?: number | null
          user_id: string
        }
        Update: {
          created_at?: string | null
          icon?: string | null
          id?: string
          is_default?: boolean | null
          name?: string
          sort_order?: number | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "game_categories_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      game_library: {
        Row: {
          added_at: string | null
          category_id: string | null
          game_id: string
          id: string
          notes: string | null
          play_count: number | null
          rating: number | null
          user_id: string
        }
        Insert: {
          added_at?: string | null
          category_id?: string | null
          game_id: string
          id?: string
          notes?: string | null
          play_count?: number | null
          rating?: number | null
          user_id: string
        }
        Update: {
          added_at?: string | null
          category_id?: string | null
          game_id?: string
          id?: string
          notes?: string | null
          play_count?: number | null
          rating?: number | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "game_library_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "game_categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "game_library_game_id_fkey"
            columns: ["game_id"]
            isOneToOne: false
            referencedRelation: "games"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "game_library_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      games: {
        Row: {
          bgg_id: number | null
          bgg_rating: number | null
          categories: string[] | null
          complexity: number
          created_at: string | null
          description: string | null
          id: string
          image_url: string | null
          max_players: number
          max_playtime: number
          mechanics: string[] | null
          min_players: number
          min_playtime: number
          name: string
          recommended_players: number[] | null
          thumbnail_url: string | null
          year_published: number | null
        }
        Insert: {
          bgg_id?: number | null
          bgg_rating?: number | null
          categories?: string[] | null
          complexity?: number
          created_at?: string | null
          description?: string | null
          id?: string
          image_url?: string | null
          max_players?: number
          max_playtime?: number
          mechanics?: string[] | null
          min_players?: number
          min_playtime?: number
          name: string
          recommended_players?: number[] | null
          thumbnail_url?: string | null
          year_published?: number | null
        }
        Update: {
          bgg_id?: number | null
          bgg_rating?: number | null
          categories?: string[] | null
          complexity?: number
          created_at?: string | null
          description?: string | null
          id?: string
          image_url?: string | null
          max_players?: number
          max_playtime?: number
          mechanics?: string[] | null
          min_players?: number
          min_playtime?: number
          name?: string
          recommended_players?: number[] | null
          thumbnail_url?: string | null
          year_published?: number | null
        }
        Relationships: []
      }
      group_members: {
        Row: {
          added_at: string | null
          display_name: string | null
          group_id: string
          id: string
          phone_number: string
          sort_order: number | null
          tier: number | null
          user_id: string | null
        }
        Insert: {
          added_at?: string | null
          display_name?: string | null
          group_id: string
          id?: string
          phone_number: string
          sort_order?: number | null
          tier?: number | null
          user_id?: string | null
        }
        Update: {
          added_at?: string | null
          display_name?: string | null
          group_id?: string
          id?: string
          phone_number?: string
          sort_order?: number | null
          tier?: number | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "group_members_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "group_members_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      groups: {
        Row: {
          created_at: string | null
          description: string | null
          emoji: string | null
          id: string
          name: string
          owner_id: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          description?: string | null
          emoji?: string | null
          id?: string
          name: string
          owner_id: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          description?: string | null
          emoji?: string | null
          id?: string
          name?: string
          owner_id?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "groups_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      invites: {
        Row: {
          created_at: string | null
          display_name: string | null
          event_id: string
          id: string
          invite_token: string | null
          is_active: boolean | null
          phone_number: string
          responded_at: string | null
          selected_time_option_ids: string[] | null
          sent_via: string | null
          sms_delivery_status: string | null
          status: string
          tier: number | null
          tier_position: number | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          display_name?: string | null
          event_id: string
          id?: string
          invite_token?: string | null
          is_active?: boolean | null
          phone_number: string
          responded_at?: string | null
          selected_time_option_ids?: string[] | null
          sent_via?: string | null
          sms_delivery_status?: string | null
          status?: string
          tier?: number | null
          tier_position?: number | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          display_name?: string | null
          event_id?: string
          id?: string
          invite_token?: string | null
          is_active?: boolean | null
          phone_number?: string
          responded_at?: string | null
          selected_time_option_ids?: string[] | null
          sent_via?: string | null
          sms_delivery_status?: string | null
          status?: string
          tier?: number | null
          tier_position?: number | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "invites_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invites_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      saved_contacts: {
        Row: {
          avatar_url: string | null
          created_at: string | null
          id: string
          is_app_user: boolean | null
          name: string
          phone_number: string
          user_id: string
        }
        Insert: {
          avatar_url?: string | null
          created_at?: string | null
          id?: string
          is_app_user?: boolean | null
          name: string
          phone_number: string
          user_id: string
        }
        Update: {
          avatar_url?: string | null
          created_at?: string | null
          id?: string
          is_app_user?: boolean | null
          name?: string
          phone_number?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "saved_contacts_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      time_option_votes: {
        Row: {
          created_at: string | null
          id: string
          invite_id: string
          time_option_id: string
        }
        Insert: {
          created_at?: string | null
          id?: string
          invite_id: string
          time_option_id: string
        }
        Update: {
          created_at?: string | null
          id?: string
          invite_id?: string
          time_option_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "time_option_votes_invite_id_fkey"
            columns: ["invite_id"]
            isOneToOne: false
            referencedRelation: "invites"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "time_option_votes_time_option_id_fkey"
            columns: ["time_option_id"]
            isOneToOne: false
            referencedRelation: "time_options"
            referencedColumns: ["id"]
          },
        ]
      }
      time_options: {
        Row: {
          created_at: string | null
          date: string
          end_time: string | null
          event_id: string
          id: string
          is_suggested: boolean | null
          label: string | null
          start_time: string
          suggested_by: string | null
          vote_count: number | null
        }
        Insert: {
          created_at?: string | null
          date: string
          end_time?: string | null
          event_id: string
          id?: string
          is_suggested?: boolean | null
          label?: string | null
          start_time: string
          suggested_by?: string | null
          vote_count?: number | null
        }
        Update: {
          created_at?: string | null
          date?: string
          end_time?: string | null
          event_id?: string
          id?: string
          is_suggested?: boolean | null
          label?: string | null
          start_time?: string
          suggested_by?: string | null
          vote_count?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "time_options_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "time_options_suggested_by_fkey"
            columns: ["suggested_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      users: {
        Row: {
          avatar_url: string | null
          bgg_username: string | null
          bio: string | null
          contacts_synced: boolean | null
          created_at: string | null
          discoverable_by_phone: boolean | null
          display_name: string
          id: string
          marketing_opt_in: boolean | null
          phone_number: string
          phone_visible: boolean | null
          privacy_accepted_at: string | null
          updated_at: string | null
        }
        Insert: {
          avatar_url?: string | null
          bgg_username?: string | null
          bio?: string | null
          contacts_synced?: boolean | null
          created_at?: string | null
          discoverable_by_phone?: boolean | null
          display_name: string
          id?: string
          marketing_opt_in?: boolean | null
          phone_number: string
          phone_visible?: boolean | null
          privacy_accepted_at?: string | null
          updated_at?: string | null
        }
        Update: {
          avatar_url?: string | null
          bgg_username?: string | null
          bio?: string | null
          contacts_synced?: boolean | null
          created_at?: string | null
          discoverable_by_phone?: boolean | null
          display_name?: string
          id?: string
          marketing_opt_in?: boolean | null
          phone_number?: string
          phone_visible?: boolean | null
          privacy_accepted_at?: string | null
          updated_at?: string | null
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const

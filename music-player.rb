require 'gosu'

# Modern dark theme palette and typography constants used across the UI
BACKGROUND_COLOR = Gosu::Color.argb(0xff_0A0A0F) #dark navy-blue background
SIDEBAR_COLOR = Gosu::Color.argb(0xff_151520) #Slightly lighter dark gray for the sidebar panel
CARD_COLOR = Gosu::Color.argb(0xff_1E1E2E) #dark gray for album cards
ACCENT_COLOR = Gosu::Color.argb(0xff_8B5CF6) #purple for accent colors
SECONDARY_ACCENT = Gosu::Color.argb(0xff_06B6D4) #cyan for secondary accent colors
TEXT_PRIMARY = Gosu::Color.argb(0xff_E2E8F0) #light gray for primary text
TEXT_SECONDARY = Gosu::Color.argb(0xff_94A3B8) #dark gray for secondary text

ARTWORK_WIDTH = 544 #width of the album artwork in pixels

# Z ordering for draw calls (lower draws behind higher)
module ZOrder
  BACKGROUND, CARDS, UI, TOP = *0..3
end

# Two screens: album grid and track list for a selected album
module ScreenType
  ALBUMS, TRACKS, ADD_TRACK = *0..2
end

# Data structures for albums and tracks
class Album
  attr_accessor :title, :artist, :artwork, :tracks

  def initialize (title, artist, artwork, tracks)
    @title = title
    @artist = artist
    @artwork = artwork
    @tracks = tracks
  end
end
#Track class for the tracks array properties of an album class
class Track
  attr_accessor :title, :location
  #allow title and location to be set in () when called, not manually done later
  def initialize (title, location)
    @title = title
    @location = location
  end
end

# ------------------ File IO -------------------
# returns an array of album objects from the albums.txt file
def read_albums(file_name)
  albums = []
  file = File.new(file_name, 'r')
  entity_count = file.gets.to_i
  
  while entity_count > 0 
    #read the album title, artist, and artwork name from the file
    album_title = file.gets().chomp
    #read the album artist from the file
    album_artist = file.gets().chomp
    #read the album artwork name from the file
    album_artwork_name = file.gets.chomp
    #read the number of tracks for this album from the file
    local_count = file.gets().to_i()
    #create an empty array for the tracks
    tracks = Array.new()
    
    # Read all tracks for this album
    while local_count > 0
      #read the track name from the file
      track_name = file.gets.chomp
      #read the track location from the file
      track_location = file.gets.chomp
      track = Track.new(track_name, track_location)
      tracks << track
      local_count = local_count - 1
    end
    
    # Create album AFTER reading all tracks
    album = Album.new(album_title, album_artist, album_artwork_name, tracks)
    albums << album
    entity_count = entity_count - 1
  end
  
  file.close
  return albums
end
# ------------------- END OF FILE IO -------------------

# returns an array of Gosu::Image objects for the album artwork in ./images/
def read_artworks(albums)
  artworks = []
  #iterate through the albums array
  i = 0

  while i < albums.length
    #create a new Gosu::Image object for the album artwork
    # Try different image formats in order: png, jpg, jpeg
    artwork_path = "images/#{albums[i].artwork}.png"
    unless File.exist?(artwork_path)
      artwork_path = "images/#{albums[i].artwork}.jpg"
      unless File.exist?(artwork_path)
        artwork_path = "images/#{albums[i].artwork}.jpeg"
      end
    end
    artworks << Gosu::Image.new(artwork_path)
    #increment the index
    i += 1
  end
  #return the array of Gosu::Image objects
  return artworks
end

# main class for the music player
class MusicPlayerMain < Gosu::Window
  #initialize the window
  def initialize
    super 1200, 800 # Wider window for sidebar layout
    #set the caption of the window
    self.caption = "Music Player"

    # Instance variables (used throughout the class)
    @albums = read_albums('albums.txt')
    @artworks = read_artworks(@albums)

    # Fonts
    @title_font = Gosu::Font.new(32)
    @header_font = Gosu::Font.new(24)
    @body_font = Gosu::Font.new(18)
    @small_font = Gosu::Font.new(14)

    # UI state
    @screen_type = ScreenType::ALBUMS #start on the albums screen (0)
    @selected_album = 0 #start on the first album (0)
    @selected_track = 0 #start on the first track (0)
    @volume = 1.0 #start at 100% volume
    @song = nil #no song is playing initially

    # Flags
    @change_track = true # flag to load new track later
    @manual_pause = false # checking if the song is paused manually
    @mute = false # not muted initially
    @is_dragging_volume = false # checking if the volume is being dragged
    @hovered_album = -1 # no album is hovered initially
    @hovered_track = -1 # no track is hovered initially
    
    # Add track UI state
    @new_track_title = ""
    @new_track_location = ""
    @focused_input = :title  # Track which input field is focused

    # Scroll/Page state for albums
    @album_scroll_offset = 0  # Vertical scroll offset for album grid
    @albums_per_page = 6  # Number of albums visible (2 rows x 3 columns)

    # Transport icons (PNG assets)
    @icon_backward = Gosu::Image.new("elements/Backward.png")
    @icon_forward  = Gosu::Image.new("elements/Forward.png")
    @icon_pause    = Gosu::Image.new("elements/Pause.png")
    @icon_play     = Gosu::Image.new("elements/Play.png")

    @speaker = Gosu::Image.new("elements/Speaker.png")
		@speaker_hover = Gosu::Image.new("elements/Speaker_Hover.png")

		@speaker_mute = Gosu::Image.new("elements/Speaker_Mute.png")
		@speaker_mute_hover = Gosu::Image.new("elements/Speaker_Mute_Hover.png")

    # Background color gradient from dark navy-blue (bg) to slightly lighter dark gray
    @bg_gradient = create_gradient(1200, 800, BACKGROUND_COLOR, Gosu::Color.argb(0xff_11111A))
  end

  # create a new image to be used later
  def create_gradient(width, height, top_color, bottom_color)
    # Gosu::render creates a canvas to draw on, then everything on the canvas
    # is outputed as a sole image, to be used elsewhere
    gradient = Gosu::render(width, height) do
      # loop through every height y (0-799) for 800px
      height.times do |y|
        # ratio is the percentage of the way down the screen we are
        ratio = y.to_f / height
        color = Gosu::Color.new(
          # alpha, red, green, blue are components of top_color(a,r,g,b) class
          # blend the top_color and bottom_color based on the ratio
          (top_color.alpha * (1 - ratio) + bottom_color.alpha * ratio).to_i,
          (top_color.red * (1 - ratio) + bottom_color.red * ratio).to_i,
          (top_color.green * (1 - ratio) + bottom_color.green * ratio).to_i,
          (top_color.blue * (1 - ratio) + bottom_color.blue * ratio).to_i
        )
        # draw a rectangle from (0,y) to (width,y+1) with the color
        Gosu.draw_rect(0, y, width, 1, color, ZOrder::BACKGROUND)
      end
    end
    return gradient
  end

  # Drawing helpers for rounded rectangles and circles
  def draw_rounded_rect(x, y, width, height, radius, color, z_order)
    Gosu.draw_rect(x + radius, y, width - 2 * radius, height, color, z_order)
    Gosu.draw_rect(x, y + radius, width, height - 2 * radius, color, z_order)
    draw_circle(x + radius, y + radius, radius, color, z_order)
    draw_circle(x + width - radius, y + radius, radius, color, z_order)
    draw_circle(x + radius, y + height - radius, radius, color, z_order)
    draw_circle(x + width - radius, y + height - radius, radius, color, z_order)
  end
  # draw a circle with the given x, y, radius, color, and z_order
  def draw_circle(x, y, radius, color, z_order)
    16.times do |i|
      angle1 = i * Math::PI / 8
      angle2 = (i + 1) * Math::PI / 8
      Gosu.draw_triangle(
        x, y, color,
        x + Math.cos(angle1) * radius, y + Math.sin(angle1) * radius, color,
        x + Math.cos(angle2) * radius, y + Math.sin(angle2) * radius, color,
        z_order
      )
    end
  end
  
  # Draw an image with rounded corners using clipping
  def draw_image_with_clipping(image, x, y, width, height, scale, z_order)
    # Create a temporary image with rounded corners
    Gosu.clip_to(x, y, width, height) do
      # Draw the actual image scaled to fit
      image.draw(x, y, z_order, scale, scale)
    end
  end

  # ----------- Screens -----------
  def draw_albums_screen
    # Sidebar
    draw_rounded_rect(0, 0, 280, 800, 0, SIDEBAR_COLOR, ZOrder::UI)
    
    # font.draw_text(text, x, y, z, scale_x, scale_y, color)
    @title_font.draw_text("NHAC", 40, 40, ZOrder::TOP, 1.0, 1.0, ACCENT_COLOR)
    @body_font.draw_text("MUSIC PLAYER", 40, 80, ZOrder::TOP, 1.0, 1.0, TEXT_SECONDARY)

    # Navigation (static for now)
    # draw_nav_item(text, x, y, active), function is defined below
    draw_nav_item("Browse Albums", 40, 160, true) # true means active
    draw_nav_item("Recently Played (N/A)", 40, 210, false) # false means inactive
    draw_nav_item("Playlists", 40, 260, false) # false means inactive
    draw_nav_item("Settings (N/A)", 40, 310, false) # false means inactive

    # Content header
    @header_font.draw_text("Your Music Collection", 320, 40, ZOrder::TOP, 1.0, 1.0, TEXT_PRIMARY)

    # Calculate how many albums to show
    # Offset 0: start = 0, 0 * 6 = 0 --> shows albums 0–5 
    # Offset 1: start = 3, 1 * 6 = 6 --> shows albums 6–11
    # Offset 2: start = 6, 2 * 6 = 12 --> shows albums 12–17
    # @album_scroll_offset is [0, 1, 2, ...]
    # used to be * 3, now * @albums_per_page (6) --> no overlap of albums on different pages
    start_index = @album_scroll_offset * @albums_per_page  # Scroll by full pages (6 albums)
    # why min? because if the albums # are not enough to fill the page, don't draw more than the number of albums
    end_index = [start_index + @albums_per_page, @albums.length].min
    
    # Draw only visible albums based on scroll position
    visible_count = 0
    i = start_index
    while i < end_index
      # calculate the column and row of the album card
      # visible_count is the number of albums visible on the screen
      # 3 columns per row, so % 3 gives the column
      # / 3 gives the row
      col = visible_count % 3
      row = visible_count / 3
      album = @albums[i]
      # first album is at (320, 100), then each album is 280px to the right and 320px down
      x_album = 320 + col * 280
      y_album = 100 + row * 320

      # Draw the album card
      # If the album is hovered, draw a lighter color, otherwise draw the default color
      card_color = (i == @hovered_album) ? Gosu::Color.argb(0xff_2A2A3A) : CARD_COLOR
      draw_rounded_rect(x_album, y_album, 240, 280, 20, card_color, ZOrder::CARDS) # CARDS is 1 in (0-3)

      # Artwork's position in the album card above
      # Scale to fit within the card bounds (175x200 area for artwork with padding)
      artwork = @artworks[i]
      target_width = 175.0
      target_height = 200.0
      
      # Calculate scale to fit the artwork within bounds
      scale_x = target_width / artwork.width
      scale_y = target_height / artwork.height
      scale = [scale_x, scale_y].min  # Use smaller scale to maintain aspect ratio
      
      # Calculate actual dimensions after scaling
      scaled_width = artwork.width * scale
      scaled_height = artwork.height * scale
      
      # Center the artwork within the available space
      artwork_x = x_album + 32.5 + (target_width - scaled_width) / 2
      artwork_y = y_album + 10 + (target_height - scaled_height) / 2
      
      # Draw artwork with clipping for rounded corners
      Gosu.clip_to(x_album + 32.5, y_album + 20, target_width, target_height) do
        artwork.draw(artwork_x, artwork_y, ZOrder::TOP, scale, scale)
      end

      # Meta of each album in the album card above
      # To center the text, we need to calculate the width of the text and then divide it by 2
      # then subtract it from the x_album to get the center position
      @body_font.draw_text(album.title, x_album + (240 - @body_font.text_width(album.title)) / 2, y_album + 210, ZOrder::TOP, 1.0, 1.0, TEXT_PRIMARY)
      @small_font.draw_text(album.artist, x_album + (240 - @small_font.text_width(album.artist)) / 2, y_album + 230, ZOrder::TOP, 1.15, 1.15, TEXT_SECONDARY)
      @small_font.draw_text("#{album.tracks.length} tracks", x_album + (240 - @small_font.text_width("#{album.tracks.length} tracks")) / 2, y_album + 250, ZOrder::TOP, 1.0, 1.0, ACCENT_COLOR)
      # the text_width method returns the width of the text in pixels
      visible_count += 1
      i += 1
    end
    
    # Draw scroll/page indicators
    draw_album_scroll_controls
  end
  
  # Draw the scroll/page indicators at the bottom of the albums screen
  def draw_album_scroll_controls
    # Round-down division to get the total number of pages
    total_pages = (@albums.length + @albums_per_page - 1) / @albums_per_page  # Ceiling division
    
    # Current page is the offset + 1 (0-indexed to 1-indexed)
    current_page = @album_scroll_offset + 1
    
    # Page indicator at the bottom
    @small_font.draw_text("Page #{current_page} of #{total_pages}", 40, 700, ZOrder::TOP, 1.0, 1.0, TEXT_SECONDARY)
    
    # Scroll up button (only if not on first page)
    if @album_scroll_offset > 0
      if mouse_on_area?(40, 620, 110, 670)
        draw_rounded_rect(40, 620, 70, 50, 10, Gosu::Color.argb(0xff_2A2A3A), ZOrder::UI)
        @body_font.draw_text("<<| Prev", 45, 635, ZOrder::TOP, 1.0, 1.0, SECONDARY_ACCENT)
      else
        draw_rounded_rect(40, 620, 70, 50, 10, CARD_COLOR, ZOrder::UI)
        @body_font.draw_text("<<| Prev", 45, 635, ZOrder::TOP, 1.0, 1.0, TEXT_PRIMARY)
      end
    end
    
    # Scroll down button (only if not on last page)
    if @album_scroll_offset < total_pages - 1
      if mouse_on_area?(140, 620, 210, 670)
        draw_rounded_rect(140, 620, 70, 50, 10, Gosu::Color.argb(0xff_2A2A3A), ZOrder::UI)
        @body_font.draw_text("Next |>>", 145, 635, ZOrder::TOP, 1.0, 1.0, SECONDARY_ACCENT)
      else
        draw_rounded_rect(140, 620, 70, 50, 10, CARD_COLOR, ZOrder::UI)
        @body_font.draw_text("Next |>>", 145, 635, ZOrder::TOP, 1.0, 1.0, TEXT_PRIMARY)
      end
    end
  end

  # Draw the navigation items in the sidebar
  # text is the text to draw
  # x is the x coordinate of the left edge of the navigation item
  # y is the y coordinate of the top edge of the navigation item
  # active is a boolean indicating if the navigation item is active
  def draw_nav_item(text, x, y, active)
    color = active ? ACCENT_COLOR : TEXT_SECONDARY
    # if the navigation item is active, draw a darker color
    if active
      draw_rounded_rect(x - 10, y - 5, 200, 40, 10, Gosu::Color.argb(0xff_2A2A3A), ZOrder::CARDS)
    end
    @body_font.draw_text(text, x, y, ZOrder::TOP, 1.0, 1.0, color)
  end

  def draw_tracks_screen(album)
    # new sidebar when clicked on a album card --> track screen
    draw_rounded_rect(0, 0, 280, 800, 0, SIDEBAR_COLOR, ZOrder::UI)
    @title_font.draw_text("NHA.C", 40, 40, ZOrder::TOP, 1.0, 1.0, ACCENT_COLOR)
    
    # Back link
    # left, top, right, bottom edges of the back link zone
    if mouse_on_area?(40, 160, 200, 180)
      draw_rounded_rect(30, 150, 160, 40, 10, Gosu::Color.argb(0xff_2A2A3A), ZOrder::UI)
      @body_font.draw_text("← Back to Albums", 40, 160, ZOrder::TOP, 1.0, 1.0, SECONDARY_ACCENT)
    else
      draw_rounded_rect(30, 150, 160, 40, 10, CARD_COLOR, ZOrder::UI)
      @body_font.draw_text("← Back to Albums", 40, 160, ZOrder::TOP, 1.0, 1.0, TEXT_PRIMARY)
    end

    # Album header panel in track screen
    # Contains the album artwork, album title, artist, and number of tracks
    draw_rounded_rect(300, 40, 860, 200, 20, CARD_COLOR, ZOrder::CARDS)

    # Cover art (clamped to header height)
    # The album artwork is scaled to the header height
    header_max_h = 160.0
    art = @artworks[@selected_album]
    # built-in height method
    # accept scale factor below or equal to 0.45 for artwork
    scale = [header_max_h / art.height, 0.45].min
    art.draw(320, 60, ZOrder::TOP, scale, scale)

    # Album meta in the album header panel above
    # Start x-coordinate for meta info, after the album artwork
    meta_x_start = 320 + (art.width * scale) + 20 # 20px padding
    panel_width_for_meta = 860 - (meta_x_start - 300)

    title_width = @title_font.text_width(album.title)
    artist_width = @body_font.text_width("by #{album.artist}")
    tracks_count_width = @small_font.text_width("#{album.tracks.length} tracks")
    play_all_width = @body_font.text_width("▶ Play All") # Actual text width
    play_all_button_width = 110 # Fixed button width

    @title_font.draw_text(album.title, meta_x_start + (panel_width_for_meta - title_width) / 2, 70, ZOrder::TOP, 1.0, 1.0, TEXT_PRIMARY)
    @body_font.draw_text("by #{album.artist}", meta_x_start + (panel_width_for_meta - artist_width) / 2, 110, ZOrder::TOP, 1.0, 1.0, TEXT_SECONDARY)
    @small_font.draw_text("#{album.tracks.length} tracks" , meta_x_start + (panel_width_for_meta - tracks_count_width) / 2, 140, ZOrder::TOP, 1.0, 1.0, ACCENT_COLOR)

    # Play all button in the album header panel above, will play from the first track
    play_button_x = meta_x_start + (panel_width_for_meta - play_all_button_width) / 2
    draw_rounded_rect(play_button_x, 170, play_all_button_width, 40, 20, ACCENT_COLOR, ZOrder::UI)
    @body_font.draw_text("▶ Play All", play_button_x + (play_all_button_width - play_all_width) / 2, 180, ZOrder::TOP, 1.05, 1.05, TEXT_PRIMARY)

    # Track list title in the track screen
    @header_font.draw_text("Tracks", 320, 262, ZOrder::TOP, 1.1, 1.1, TEXT_PRIMARY)
    
    # Add Track button
    if mouse_on_area?(1020, 258, 1160, 290)
      draw_rounded_rect(1020, 258, 140, 35, 10, Gosu::Color.argb(0xff_2A2A3A), ZOrder::UI)
      @body_font.draw_text("+ Add Track", 1035 + 8, 265 + 3, ZOrder::TOP, 1.0, 1.0, SECONDARY_ACCENT)
    else
      draw_rounded_rect(1020, 258, 140, 35, 10, CARD_COLOR, ZOrder::UI)
      @body_font.draw_text("+ Add Track", 1035 + 8, 265 + 3, ZOrder::TOP, 1.0, 1.0, TEXT_PRIMARY)
    end

    i = 0
    while i < album.tracks.length
      track = album.tracks[i]
      y_track = 330 + i * 50
      track_bg = (i == @selected_track) ? Gosu::Color.argb(0xff_2A2A3A) : 
                 (i == @hovered_track) ? Gosu::Color.argb(0xff_252535) : CARD_COLOR
      draw_rounded_rect(320, y_track, 840, 40, 10, track_bg, ZOrder::CARDS)
      @body_font.draw_text((i + 1).to_s.rjust(2, '0'), 340, y_track + 12, ZOrder::TOP, 1.0, 1.0, TEXT_SECONDARY)
      track_color = (i == @selected_track) ? ACCENT_COLOR : TEXT_PRIMARY
      @body_font.draw_text(track.title, 380, y_track + 12, ZOrder::TOP, 1.0, 1.0, track_color)
      if i == @selected_track && @song && @song.playing?
        @body_font.draw_text("▶", 1140-20, y_track-20, ZOrder::TOP, 4.5, 4.5, SECONDARY_ACCENT)
      end
      i += 1
    end

    # Now playing
    draw_now_playing_bar(album)
  end

  # Bottom now-playing panel (artwork + transport + volume)
  def draw_now_playing_bar(album)
    return unless @song && album.tracks[@selected_track]
    
    draw_rounded_rect(280, 700, 880, 80, 20, CARD_COLOR, ZOrder::UI)
    current_track = album.tracks[@selected_track]
    
    # Artwork scaled to panel height
    art_np = @artworks[@selected_album]
    # panel_h is the height of the now-playing panel
    # max_h is the maximum height of the artwork
    panel_h = 80.0
    max_h = panel_h - 20.0
    # scale_np is the scale factor of the artwork
    # height method built-in
    # accept scale factor below or equal to 0.15 for artwork
    scale_np = [max_h / art_np.height, 0.15].min # min is to ensure the scale factor is not too large
    scaled_h = art_np.height * scale_np
    y_np = 700 + (panel_h - scaled_h) / 2.0
    art_np.draw(300, y_np, ZOrder::TOP, scale_np, scale_np) # draw the artwork

    # Titles
    @body_font.draw_text(current_track.title, 370, 715, ZOrder::TOP, 1.0, 1.0, TEXT_PRIMARY)
    @small_font.draw_text(album.artist, 370, 740, ZOrder::TOP, 1.0, 1.0, TEXT_SECONDARY)
    
    # Transport (play/pause, previous, next)
    draw_control_buttons(650, 740)
    
    # Volume (icon + bar) (drag to change volume)
    draw_volume_control(900, 730)
  end

  # Draw the three transport buttons (previous, play/pause, next) with icons
  # The function is called in the draw_now_playing_bar function
  def draw_control_buttons(x, y)
    # Previous
    draw_circle(x, y, 24, CARD_COLOR, ZOrder::CARDS)
    draw_circle(x, y, 23, SECONDARY_ACCENT, ZOrder::UI)
    @icon_backward.draw(x - 20, y - 20, ZOrder::UI)

    # Play/Pause
    draw_circle(x + 60, y, 28, CARD_COLOR, ZOrder::CARDS)
    draw_circle(x + 60, y, 27, ACCENT_COLOR, ZOrder::UI)
    if @manual_pause
      @icon_play.draw(x + 60 - 20, y - 20, ZOrder::UI)
    else
      @icon_pause.draw(x + 60 - 20, y - 20, ZOrder::UI)
    end

    # Next
    draw_circle(x + 120, y, 24, CARD_COLOR, ZOrder::CARDS)
    draw_circle(x + 120, y, 23, SECONDARY_ACCENT, ZOrder::UI)
    @icon_forward.draw(x + 120 - 20, y - 20, ZOrder::UI)
  end


  # Volume control: icon + larger, easy-to-drag bar
  # x and y are the coordinates of the volume control block (icon + bar)
  def draw_volume_control(x, y)
    # Icon toggles mute in the click handler
    # Draw the appropriate icon based on mute state
    icon_scale = 1.2  # Scale the icon up
    if @mute
      @speaker_mute.draw(x, y - 5, ZOrder::TOP, icon_scale, icon_scale)
    else
      @speaker.draw(x, y - 5, ZOrder::TOP, icon_scale, icon_scale)
    end
    
    # Volume bar dimensions
    bar_left = x + 40
    bar_top = y + 5
    bar_width = 160
    bar_height = 10 + 4  # Increased from 10 to make it thicker

    # Track (background)
    draw_rounded_rect(bar_left, bar_top, bar_width, bar_height, 5, Gosu::Color.argb(0xff_333344), ZOrder::TOP)

    # Fill width (clamped to [0, bar_width]) to avoid bleed at the edges
    clamped_volume = [[(@mute ? 0 : @volume), 0].max, 1.0].min
    volume_width = (clamped_volume * bar_width).to_f
    # Ensure width stays within bounds - must be at least radius to draw properly
    volume_width = [[volume_width, 0].max, bar_width].min
    
    # Only draw if width is enough to render without overflow
    if volume_width > 0
      # For very thin fills, use a simple rectangle to avoid circle overflow
      if volume_width < 10  # Less than 2*radius
        Gosu.draw_rect(bar_left, bar_top, volume_width, bar_height, SECONDARY_ACCENT, ZOrder::TOP)
      else
        draw_rounded_rect(bar_left, bar_top, volume_width, bar_height, 5, SECONDARY_ACCENT, ZOrder::TOP)
      end
    end
  end

  # Global background and footer credit
  def draw_background
    @bg_gradient.draw(0, 0, ZOrder::BACKGROUND)
  end

  def draw_credit
    credit_text = "Nha.c Player © 2025"
    @small_font.draw_text(credit_text, 40, 760, ZOrder::TOP, 1.0, 1.0, TEXT_SECONDARY)
  end

  # In draw function, repeatedly called by Gosu to draw/update the current screen
  def draw
    # draw the background gradient
    draw_background()

    # draw the current screen based on the screen type
    # three screens: albums, tracks, add track
    case @screen_type
    when ScreenType::ALBUMS
      draw_albums_screen()
    when ScreenType::TRACKS
      draw_tracks_screen(@albums[@selected_album])
    when ScreenType::ADD_TRACK
      draw_add_track_screen()
    end

    # draw the footer credit
    draw_credit()
  end

  # called in the draw function above
  # draw the add track screen
  def draw_add_track_screen
    # new sidebar when clicked on a album card --> track screen
    draw_rounded_rect(0, 0, 280, 800, 0, SIDEBAR_COLOR, ZOrder::UI)
    @title_font.draw_text("NHA.C", 40, 40, ZOrder::TOP, 1.0, 1.0, ACCENT_COLOR)
    
    # Back link
    # left, top, right, bottom edges of the back link zone
    if mouse_on_area?(40, 160, 240, 200)
      draw_rounded_rect(30, 150, 160, 40, 10, Gosu::Color.argb(0xff_2A2A3A), ZOrder::UI)
      @body_font.draw_text("← Back to Tracks", 40, 160, ZOrder::TOP, 1.0, 1.0, SECONDARY_ACCENT)
    else
      draw_rounded_rect(30, 150, 160, 40, 10, CARD_COLOR, ZOrder::UI)
      @body_font.draw_text("← Back to Tracks", 40, 160, ZOrder::TOP, 1.0, 1.0, TEXT_PRIMARY)
    end
    
    # Content area (album title, track title, file path, save button)
    draw_rounded_rect(300, 100, 860, 580, 20, CARD_COLOR, ZOrder::CARDS)
    
    album = @albums[@selected_album]
    
    # Header
    @title_font.draw_text("Add New Track", 340, 120, ZOrder::TOP, 1.0, 1.0, TEXT_PRIMARY)
    @body_font.draw_text("to #{album.title}", 340, 165, ZOrder::TOP, 1.0, 1.0, TEXT_SECONDARY)
    
    
    # Title input with focus indicator
    title_bg = @focused_input == :title ? Gosu::Color.argb(0xff_1A1A2A) : Gosu::Color.argb(0xff_0A0A0F)
    @body_font.draw_text("Track Title:", 340, 240, ZOrder::TOP, 1.0, 1.0, TEXT_PRIMARY)
    draw_rounded_rect(340, 270, 780, 50, 10, title_bg, ZOrder::UI)
    display_title = @new_track_title.empty? ? "Enter track title..." : @new_track_title
    title_color = @new_track_title.empty? ? TEXT_SECONDARY : TEXT_PRIMARY
    @body_font.draw_text(display_title, 350, 285, ZOrder::TOP, 1.0, 1.0, title_color)
    
    # File path input with focus indicator
    path_bg = @focused_input == :location ? Gosu::Color.argb(0xff_1A1A2A) : Gosu::Color.argb(0xff_0A0A0F)
    @body_font.draw_text("File Path:", 340, 350, ZOrder::TOP, 1.0, 1.0, TEXT_PRIMARY)
    draw_rounded_rect(340, 380, 780, 50, 10, path_bg, ZOrder::UI)
    display_path = @new_track_location.empty? ? "Enter file path..." : @new_track_location
    path_color = @new_track_location.empty? ? TEXT_SECONDARY : TEXT_PRIMARY
    @body_font.draw_text(display_path, 350, 395, ZOrder::TOP, 1.0, 1.0, path_color)
    
    # Save button
    save_enabled = !@new_track_title.empty? && !@new_track_location.empty?
    if mouse_on_area?(340, 470, 540, 510)
      draw_rounded_rect(340, 470, 200, 40, 10, 
        save_enabled ? Gosu::Color.argb(0xff_2A2A3A) : Gosu::Color.argb(0xff_1A1A1A), ZOrder::UI)
      @body_font.draw_text("Add Track", 400, 480, ZOrder::TOP, 1.0, 1.0, 
        save_enabled ? SECONDARY_ACCENT : TEXT_SECONDARY)
    else
      draw_rounded_rect(340, 470, 200, 40, 10, 
        save_enabled ? CARD_COLOR : Gosu::Color.argb(0xff_1A1A1A), ZOrder::UI)
      @body_font.draw_text("Add Track", 400, 480, ZOrder::TOP, 1.0, 1.0, 
        save_enabled ? TEXT_PRIMARY : TEXT_SECONDARY)
    end
  end

  # Utility: simple rect hit test
  def mouse_on_area?(leftX, topY, rightX, bottomY)
    return mouse_x.between?(leftX, rightX) && mouse_y.between?(topY, bottomY)
  end

  # show the cursor
  def needs_cursor?; true; end

  # Per-frame updates: playback state, volume dragging, and hover state
  def update
    # Hover feedback for album grid / track list
    # update the hover states variable @hovered_album(index) and @hovered_track(index)
    update_hover_states
    
    case @screen_type
    when ScreenType::TRACKS
      # get the album object from the selected album index
      album = @albums[@selected_album]

      # Lazy-load and start a track when state requests a change
      # Flag to load new track or not, if true, load the new track later
      if @change_track
        # if there is a song playing, stop it
        if @song != nil
          @song.stop
        end
        # load the song from the file path
        # @selected_track is the index of the track to play
        # album.tracks[@selected_track].location is the file path of the track to play
        @song = Gosu::Song.new(album.tracks[@selected_track].location)
        # @song.play(false) plays the song
        # false means only play the song once
        @song.play(false)
        # @change_track = false means no looping song again
        @change_track = false
      end

      # Auto-advance when a song ends (unless paused manually)
      # not @song.playing? means the song is not playing
      # not @manual_pause means the song is not paused manually
      # @selected_track = (@selected_track + 1) % album.tracks.length means the next track
      # % album.tracks.length means the next track is the next track in the album
      # @change_track = true means loading new track later
      if (not @song.playing?) and (not @manual_pause)
        @selected_track = (@selected_track + 1) % album.tracks.length
        @change_track = true # flag to load new track later
      end

      # Apply mute/volume
      # @mute means the song is muted
      if @mute
        # set the volume to 0
        @song.volume = 0
      else
        # set the volume to the current volume
        @song.volume = @volume
      end

      # Volume dragging on the bottom bar
      if @is_dragging_volume
        # set the left bar position
        bar_left = 900 + 40
        # set the right bar position
        bar_right = bar_left + 160
        if mouse_x < bar_left
          # set the volume to 0
          @volume = 0
          # set the mute flag to true
          @mute = true  # Automatically mute when volume is dragged to zero
        elsif mouse_x > bar_right
          @volume = 1.0
          @mute = false
        else
          @volume = (mouse_x - bar_left) / 160.0
          @mute = (@volume == 0)  # Mute if volume is exactly zero
        end
      end
    end
  end

  # Compute hover targets for album and track lists
  def update_hover_states
    # -1 is the default value for no album or track hovered because index starts at 0
    @hovered_album = -1 #no album is hovered initially
    @hovered_track = -1 #no track is hovered initially
    
    case @screen_type
    when ScreenType::ALBUMS
      # Calculate visible range
      start_index = @album_scroll_offset * @albums_per_page
      end_index = [start_index + @albums_per_page, @albums.length].min
      
      visible_count = 0
      i = start_index
      # looping through all albums, then checking if the mouse is on any of the album cards
      while i < end_index
        col = visible_count % @albums_per_page
        row = visible_count / @albums_per_page
        x_album = 320 + col * 280
        y_album = 100 + row * 320
        if mouse_on_area?(x_album, y_album, x_album + 240, y_album + 280) # if the mouse is on the album card
          @hovered_album = i # set the hovered album index to the current album index
        end
        visible_count += 1 # increment the visible count
        i += 1 # increment the album index
      end

    # looping through all tracks, then checking if the mouse is on any of the track cards
    when ScreenType::TRACKS
      i = 0
      while i < @albums[@selected_album].tracks.length
        y_track = 330 + i * 50
        if mouse_on_area?(320, y_track, 1160, y_track + 40)
          @hovered_track = i
        end
        i += 1
      end
    end
  end

  # Gosu callback that automatically gets called 
  #whenever ANY button is pressed (mouse, keyboard, etc.)
  def button_down(id)
    # id is a number representing which button was pressed
    case id
    # This code runs ONLY when left mouse button is clicked
    when Gosu::MsLeft
      case @screen_type
      when ScreenType::ALBUMS
        handle_mouse_albums_screen(mouse_x, mouse_y) # handle the mouse click on the album cards
      when ScreenType::TRACKS
        handle_mouse_tracks_screen(mouse_x, mouse_y) # handle the mouse click on the track cards
      when ScreenType::ADD_TRACK
        handle_mouse_add_track_screen(mouse_x, mouse_y) # handle the mouse click on the add track screen
      end
    end
    # Handle keyboard input for add track screen
    if @screen_type == ScreenType::ADD_TRACK
      handle_keyboard_input(id) # handle the keyboard input for the add track screen
    end
  end
  
  # handle the keyboard input for the add track screen
  def handle_keyboard_input(id)
    # Handle special keys (space, enter, tab, backspace, escape)
    case id
    when Gosu::KB_SPACE
      add_char(' ') # add a space to the focused input 
    when Gosu::KB_RETURN
      # Enter: behave like Tab when on title; submit when on location (if valid)
      # @focused_input is the current focused input field
      # :title is the title input field
      # :location is the location input field
      # After pressing "Enter", change focus to the location input field
      if @focused_input == :title
        @focused_input = :location # switch to the location input field
      else
        # if the title and location are not empty, add the new track to the selected album
        # after pressing "Enter".
        if !@new_track_title.empty? && !@new_track_location.empty?
          # get the album object from the selected album index
          album = @albums[@selected_album]
          new_track = Track.new(@new_track_title, @new_track_location)
          album.tracks << new_track
          @new_track_title = ""
          @new_track_location = ""
          @focused_input = :title
          @screen_type = ScreenType::TRACKS
        end
      end
    when Gosu::KB_TAB
      # Switch between title and location fields
      @focused_input = (@focused_input == :title) ? :location : :title
    when Gosu::KB_BACKSPACE
      # Delete last character from focused field
      if @focused_input == :title && !@new_track_title.empty?
        # [0...-1] is everything except the last character.
        @new_track_title = @new_track_title[0...-1]
      elsif @focused_input == :location && !@new_track_location.empty?
        # [0...-1] is everything except the last character.
        @new_track_location = @new_track_location[0...-1]
      end
    when Gosu::KB_ESCAPE
      @screen_type = ScreenType::TRACKS
      @new_track_title = ""
      @new_track_location = ""
      @focused_input = :title
    else
      # Get the character from key code
      char = get_key_char(id)
      if char
        add_char(char)
      end
    end
  end
  # ------------------------------------------------- UP TO HERE  -------------------------------------------------
  def add_char(char)
    if @focused_input == :title
      @new_track_title += char
    elsif @focused_input == :location
      @new_track_location += char
    end
  end
  
  # get the character from the key code
  def get_key_char(key_id)
    # Map common key codes to characters (lowercase by default)
    # hash map of Key-Value pairs
    # key_map[key_id] gives the character for the key code
    key_map = {
      # Gosu::KB_A gives the number, not the letter 'a' directly
      Gosu::KB_A => 'a', Gosu::KB_B => 'b', Gosu::KB_C => 'c', Gosu::KB_D => 'd',
      Gosu::KB_E => 'e', Gosu::KB_F => 'f', Gosu::KB_G => 'g', Gosu::KB_H => 'h',
      Gosu::KB_I => 'i', Gosu::KB_J => 'j', Gosu::KB_K => 'k', Gosu::KB_L => 'l',
      Gosu::KB_M => 'm', Gosu::KB_N => 'n', Gosu::KB_O => 'o', Gosu::KB_P => 'p',
      Gosu::KB_Q => 'q', Gosu::KB_R => 'r', Gosu::KB_S => 's', Gosu::KB_T => 't',
      Gosu::KB_U => 'u', Gosu::KB_V => 'v', Gosu::KB_W => 'w', Gosu::KB_X => 'x',
      Gosu::KB_Y => 'y', Gosu::KB_Z => 'z',
      Gosu::KB_0 => '0', Gosu::KB_1 => '1', Gosu::KB_2 => '2', Gosu::KB_3 => '3',
      Gosu::KB_4 => '4', Gosu::KB_5 => '5', Gosu::KB_6 => '6', Gosu::KB_7 => '7',
      Gosu::KB_8 => '8', Gosu::KB_9 => '9',
      Gosu::KB_SLASH => '/', Gosu::KB_PERIOD => '.', Gosu::KB_MINUS => '-'
    }
    char = key_map[key_id]
    # Uppercase letters when Shift is held
    # characters have numeric values behind the scenes (ASCII/Unicode), so you can compare them like numbers
    # Ie. 'a' = 97, 'b' = 98, 'c' = 99, ... 'z' = 122
    if char && char >= 'a' && char <= 'z'
      if button_down?(Gosu::KB_LEFT_SHIFT) || button_down?(Gosu::KB_RIGHT_SHIFT)
        return char.upcase
      end
    end
    char
  end

  # Album grid clicks -> open track list
  def handle_mouse_albums_screen(x, y)
    # Handle scroll button clicks first
    # We don't @albums.length / @albums_per_page cuz
    # Ruby auto rounds down to the nearest integer, no need to add .ceil
    total_pages = (@albums.length + @albums_per_page - 1) / @albums_per_page
    
    # Previous page button
    # @album_scroll_offset is the current page index, only {0, 1} currently
    if @album_scroll_offset > 0 && mouse_on_area?(40, 620, 110, 670)
      @album_scroll_offset -= 1
      return
    end
    
    # Next page button
    if @album_scroll_offset < total_pages - 1 && mouse_on_area?(140, 620, 210, 670)
      @album_scroll_offset += 1
      return
    end
    
    # Calculate visible range
    start_index = @album_scroll_offset * @albums_per_page
    end_index = [start_index + @albums_per_page, @albums.length].min
    
    visible_count = 0
    i = start_index
    while i < end_index
      col = visible_count % 3
      row = visible_count / 3
      x_album = 320 + col * 280
      y_album = 100 + row * 320
      if mouse_on_area?(x_album, y_album, x_album + 240, y_album + 280)
        # if the mouse is on the album card, set the selected album to the current album
        @selected_album = i
        # set the screen type to track screen
        @screen_type = ScreenType::TRACKS
        # set the selected track to the first track
        @selected_track = 0
        # set the change track flag to true
        @change_track = true
        break # break out of the loop
      end
      # if mouse is on the album card, draw the album card
      visible_count += 1
      i += 1
    end
  end

  # Track screen interactions: back link, track select, transport, volume
  def handle_mouse_tracks_screen(x, y)
    album = @albums[@selected_album]
    
    # Back link
    if mouse_on_area?(40, 160, 240, 200)
      @screen_type = ScreenType::ALBUMS
      @selected_track = 0
      @song.stop if @song
      @change_track = true
      @manual_pause = false
      return
    end

    # Play all (from first track)
    if mouse_on_area?(600, 170, 750, 210)
      @selected_track = 0
      @change_track = true
      @manual_pause = false
    end
    
    # Add Track button
    if mouse_on_area?(1020, 258, 1160, 295)
      @new_track_title = ""
      @new_track_location = ""
      @screen_type = ScreenType::ADD_TRACK
    end

    # Track selection
    i = 0
    while i < album.tracks.length
      y_track = 330 + i * 50
      if mouse_on_area?(320, y_track, 1160, y_track + 40)
        if @selected_track != i
          @selected_track = i
          @change_track = true
          @manual_pause = false
        end
        break
      end
      i += 1
    end

    # Transport buttons
    # if the mouse is clicked on the previous button
    if point_in_circle?(mouse_x, mouse_y, 650, 740, 24) # Previous
      # @selected_track is the index of the current track
      # album.tracks.length is the total number of tracks in the album
      # % album.tracks.length is the modulo operation, it gives the remainder when @selected_track is divided by album.tracks.length
      # the remainder is the index of the previous track
      # ie. if @selected_track is 2, and album.tracks.length is 3, then 
      # 1/3 = 0.33 or rounded to 0, so remainder is 1 -> the previous track is 1
      @selected_track = (@selected_track - 1) % album.tracks.length
      # set the change track flag to true
      @change_track = true
      # if the mouse is clicked on the play/pause button
    elsif point_in_circle?(mouse_x, mouse_y, 710, 740, 28) # Play/Pause
      if @song.playing?
        @song.pause
      else
        # false means only play the song once
        @song.play(false)
      end
      @manual_pause = (not @manual_pause)
      # if the mouse is clicked on the next button
    elsif point_in_circle?(mouse_x, mouse_y, 770, 740, 24) # Next
      @selected_track = (@selected_track + 1) % album.tracks.length
      @change_track = true
    end

    # Volume bar: click-to-set and start dragging (use enlarged hitbox)
    # mouse_on_area? returns true if the mouse is on the area, false otherwise
    # In Gosu, mouse_x and mouse_y are built-in methods provided by the Gosu::Window class, not instance variables that need initialization.
    if mouse_on_area?(900 + 40, 730 + 5, 900 + 200, 730 + 25)
      @is_dragging_volume = true
      bar_left = 900 + 40
      bar_width = 160.0
      @volume = [[(mouse_x - bar_left) / bar_width, 0].max, 1.0].min
      @mute = (@volume == 0)  # Mute if volume is zero
    end

    # Mute toggle (icon)
    if mouse_on_area?(900, 720, 920, 750)
      if @mute
        # Unmute: restore the last volume level, or set to 50% if volume was 0
        @mute = false
        if @volume == 0
          @volume = 0.5  # Default to half volume if unmuting from zero
        end
      else
        # Mute: set volume to 0 but keep the volume level in memory
        @mute = true
      end
    end
  end

  # Stop volume dragging on mouse release
  # built-in callback method in Gosu that automatically gets called when a mouse button or keyboard key is released.
  # id is a number representing which button was released
  def button_up(id)
    case id
    when Gosu::MsLeft
      # set the dragging volume flag to false
      @is_dragging_volume = false
    end
  end

  # Add track screen interactions
  def handle_mouse_add_track_screen(x, y)
    # Back button
    # mouse_on_area? returns true if the mouse is on the area, false otherwise
    if mouse_on_area?(40, 160, 240, 200)
      @screen_type = ScreenType::TRACKS
      @new_track_title = ""
      @new_track_location = ""
      @focused_input = :title
      return
    end
    
    # Title input field
    if mouse_on_area?(340, 270, 1120, 320)
      @focused_input = :title
      return
    end
    
    # Location input field
    if mouse_on_area?(340, 380, 1120, 430)
      @focused_input = :location
      return
    end
    
    # ------------ These code below only runs when the none of the above buttons are clicked ------------
    # Save button
    save_enabled = !@new_track_title.empty? && !@new_track_location.empty?
    if save_enabled && mouse_on_area?(340, 470, 540, 510)
      # Add the new track to the selected album
      album = @albums[@selected_album]
      new_track = Track.new(@new_track_title, @new_track_location)
      album.tracks << new_track
      
      # Reset form and go back to tracks screen
      @new_track_title = ""
      @new_track_location = ""
      @focused_input = :title
      @screen_type = ScreenType::TRACKS
    end
  end

  # Geometry helper
  def point_in_circle?(px, py, cx, cy, r)
    dx = px - cx
    dy = py - cy
    dx * dx + dy * dy <= r * r
  end
end

MusicPlayerMain.new.show if __FILE__ == $0
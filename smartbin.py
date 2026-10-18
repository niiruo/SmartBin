import tkinter as tk
from pathlib import Path
from tkinter import messagebox
from tkinter import font as tkfont

BG = "#151517"
CONTAINER = "#303030"
PANEL = "#1c1c1f"
BORDER = "#626267"
TEXT = "#f5f5f7"
MUTED = "#d0d0d3"
BLUE = "#2468f2"
RED = "#e04b4b"  # log out
COVER = "#565656"  # profile cover banner / points card gray
BLACK = "#000000"  # coupon row background


def rounded_rect(canvas, x1, y1, x2, y2, radius=16, **kwargs):
    """Draw a smooth rounded rectangle on a Canvas."""
    points = [
        x1 + radius, y1,
        x2 - radius, y1,
        x2, y1,
        x2, y1 + radius,
        x2, y2 - radius,
        x2, y2,
        x2 - radius, y2,
        x1 + radius, y2,
        x1, y2,
        x1, y2 - radius,
        x1, y1 + radius,
        x1, y1
    ]
    return canvas.create_polygon(points, smooth=True, splinesteps=24, **kwargs)


class SmartBinLogin:
    def __init__(self, root):
        self.root = root
        self.root.title("Smart Bin | Login")
        self.root.geometry("396x760")
        self.root.minsize(360, 680)
        self.root.configure(bg=BG)

        # Main canvas lets us draw rounded UI elements.
        self.canvas = tk.Canvas(root, bg=BG, highlightthickness=0)
        self.canvas.pack(fill="both", expand=True)
        self.canvas.bind("<Configure>", self.draw_ui)

        # -------- App / navigation state --------
        self.screen = "login"
        self.user = {"first_name": "", "last_name": "", "email": "", "phone": ""}
        self.points = 50
        self.current_code = ""
        self._signup_temp = {}

        # StringVars persist across redraws/screen changes so typed text
        # is never lost (same trick the original login fields used).
        self._vars = {}
        self._entries = {}

        self.logo_image = None
        self._logo_cache = {}
        try:
            # smartbin_logo.png 
            self.logo_image = tk.PhotoImage(file=str(Path(__file__).with_name('smartbin_logo.png')))
        except tk.TclError:
            self.logo_image = None

        self.profile_image = None
        self._profile_cache = {}
        try:
            # profile.png
            self.profile_image = tk.PhotoImage(file=str(Path(__file__).with_name('profile.png')))
        except tk.TclError:
            self.profile_image = None

    # Small shared helpers (colors/fonts/spacing all match the

    def get_var(self, key):
        if key not in self._vars:
            self._vars[key] = tk.StringVar()
        return self._vars[key]

    def field_value(self, key, placeholder):
        """Returns '' if the field still shows its placeholder hint."""
        val = self.get_var(key).get()
        if val.strip() in ("", placeholder):
            return ""
        return val.strip()

    def navigate(self, screen):
        self.screen = screen
        self.draw_ui()

    def _destroy_entries(self):
        for entry in self._entries.values():
            try:
                entry.destroy()
            except tk.TclError:
                pass
        self._entries.clear()

    def get_logo(self, max_size=88):
        """Returns the Smart Bin logo scaled (by whole-number subsample)
        to fit within max_size x max_size, or None if missing."""
        if self.logo_image is None:
            return None
        if max_size not in self._logo_cache:
            logo = self.logo_image
            scale = max(
                1,
                (logo.width() + max_size - 1) // max_size,
                (logo.height() + max_size - 1) // max_size
            )
            if scale > 1:
                logo = self.logo_image.subsample(scale, scale)
            self._logo_cache[max_size] = logo
        return self._logo_cache[max_size]

    def get_profile_avatar(self, max_size=68):
        """Returns the default profile picture scaled (by whole-number
        subsample) to fit within max_size x max_size, or None if missing."""
        if self.profile_image is None:
            return None
        if max_size not in self._profile_cache:
            img = self.profile_image
            scale = max(
                1,
                (img.width() + max_size - 1) // max_size,
                (img.height() + max_size - 1) // max_size
            )
            if scale > 1:
                img = self.profile_image.subsample(scale, scale)
            self._profile_cache[max_size] = img
        return self._profile_cache[max_size]

    def make_field(self, c, x1, y1, x2, height, key, placeholder, show=None):
        """Draws a rounded field box (same style as the original email/
        password boxes) and embeds a hint-aware Entry inside it."""
        rounded_rect(c, x1, y1, x2, y1 + height, radius=15, fill=BG, outline=BORDER, width=1)

        var = self.get_var(key)
        if var.get() == "":
            var.set(placeholder)

        entry = tk.Entry(
            c, textvariable=var, bg=BG, fg=TEXT if var.get() != placeholder else MUTED,
            insertbackground=TEXT, relief="flat", bd=0,
            font=("Arial", 13), highlightthickness=0
        )
        if show and var.get() != placeholder:
            entry.config(show=show)

        def focus_in(event, var=var, entry=entry, placeholder=placeholder, show=show):
            if var.get() == placeholder:
                var.set("")
                entry.config(fg=TEXT)
                if show:
                    entry.config(show=show)

        def focus_out(event, var=var, entry=entry, placeholder=placeholder, show=show):
            if not var.get().strip():
                if show:
                    entry.config(show="")
                entry.config(fg=MUTED)
                var.set(placeholder)

        entry.bind("<FocusIn>", focus_in)
        entry.bind("<FocusOut>", focus_out)

        c.create_window(x1 + 14, y1 + height / 2, window=entry, anchor="w",
                         width=(x2 - x1) - 28, height=30)
        self._entries[key] = entry
        return entry

    def make_button(self, c, x1, y1, x2, height, text, command, bg=BLUE, fg="white", radius=14):
        rounded_rect(c, x1, y1, x2, y1 + height, radius=radius, fill=bg, outline=BORDER, width=1)
        label = c.create_text((x1 + x2) / 2, y1 + height / 2, text=text,
                               fill=fg, font=("Arial", 13, "bold"))
        c.tag_bind(label, "<Button-1>", lambda e: command())
        c.tag_bind(label, "<Enter>", lambda e: c.config(cursor="hand2"))
        c.tag_bind(label, "<Leave>", lambda e: c.config(cursor=""))
        return label

    def make_link(self, c, x, y, text, command, anchor="w", color=TEXT, size=10, underline=True):
        item = c.create_text(x, y, text=text, fill=color, font=("Arial", size), anchor=anchor)
        bbox = c.bbox(item)
        if underline and bbox:
            c.create_line(bbox[0], bbox[3] + 1, bbox[2], bbox[3] + 1, fill=color, width=1)
        c.tag_bind(item, "<Button-1>", lambda e: command())
        c.tag_bind(item, "<Enter>", lambda e: c.config(cursor="hand2"))
        c.tag_bind(item, "<Leave>", lambda e: c.config(cursor=""))
        return item

    def draw_underlined_line(self, c, center_x, y, segments, color=MUTED, size=10):
        """Draws a single centered line made of (text, underline) segments,
        each measured with the real font metrics so an underline always
        matches the width of the word(s) it sits under exactly."""
        f = tkfont.Font(family="Arial", size=size)
        total_width = sum(f.measure(text) for text, _underline in segments)
        x = center_x - total_width / 2
        for text, underline in segments:
            item = c.create_text(x, y, text=text, fill=color, font=("Arial", size), anchor="w")
            if underline:
                bbox = c.bbox(item)
                c.create_line(bbox[0], bbox[3] + 1, bbox[2], bbox[3] + 1, fill=color, width=1)
            x += f.measure(text)

    def draw_top_panel(self, c, w, h, title="Smart Bin", panel_height=None):
        """The original big rounded brand panel with the logo + name,
        used on the login / sign up / forgot-password / account screens.
        Pass panel_height for a shorter fixed-size panel (personal
        details, edit profile, change password)."""
        center = w / 2
        top_bottom = panel_height if panel_height is not None else int(h * 0.405)
        rounded_rect(c, 1, -20, w - 1, top_bottom, radius=22,
                     fill=BG, outline=BORDER, width=1)

        logo_y = int(top_bottom * 0.43)
        logo = self.get_logo(88)
        c.create_image(center, logo_y + 7, image=logo, anchor="center")
        brand_y = logo_y + 65

        c.create_text(center, brand_y, text=title, fill=TEXT, font=("Arial", 16))
        return top_bottom

    def draw_header_bar(self, c, w, title):
        """The flush top bar used on the Dashboard (the app's home
        screen), matching the design mockup: full-width, no rounding,
        just a thin divider line under it."""
        header_h = 50
        c.create_rectangle(0, 0, w, header_h, fill=BG, outline="")
        c.create_line(0, header_h, w, header_h, fill=BORDER, width=1)

        text_x = 18
        logo = self.get_logo(24)
        c.create_image(text_x, header_h / 2, image=logo, anchor="w")
        text_x += 26

        c.create_text(text_x, header_h / 2, text=title, fill=TEXT,
                       font=("Arial", 13, "bold"), anchor="w")
        return header_h

    # Central redraw dispatcher

    def draw_ui(self, event=None):
        c = self.canvas
        self._destroy_entries()
        c.delete("all")

        w = max(c.winfo_width(), 360)
        h = max(c.winfo_height(), 680)

        titles = {
            "login": "Smart Bin | Login",
            "signup_details": "Smart Bin | Sign up",
            "create_account": "Smart Bin | Create account",
            "forgot": "Smart Bin | Forgot password",
            "dashboard": "Smart Bin | Dashboard",
            "profile": "Smart Bin | Profile",
            "personal_details": "Smart Bin | Personal details",
            "edit_profile": "Smart Bin | Edit profile",
            "change_password": "Smart Bin | Change password",
        }
        self.root.title(titles.get(self.screen, "Smart Bin"))

        screen_map = {
            "login": self.draw_login,
            "signup_details": self.draw_signup_details,
            "create_account": self.draw_create_account,
            "forgot": self.draw_forgot,
            "dashboard": self.draw_dashboard,
            "profile": self.draw_profile,
            "personal_details": self.draw_personal_details,
            "edit_profile": self.draw_edit_profile,
            "change_password": self.draw_change_password,
        }
        screen_map.get(self.screen, self.draw_login)(c, w, h)

    # Login 

    def draw_login(self, c, w, h):
        center = w / 2
        top_bottom = self.draw_top_panel(c, w, h)

        title_y = top_bottom + int((h - top_bottom) * 0.14)
        c.create_text(center, title_y, text="Login", fill=TEXT, font=("Arial", 30, "bold"))

        field_left, field_right = 50, w - 50
        field_h = 53
        email_y = title_y + 42
        pass_y = email_y + 65

        self.make_field(c, field_left, email_y, field_right, field_h, "login_email", "Email:")
        self.make_field(c, field_left, pass_y, field_right, field_h, "login_password", "Password:", show="•")

        links_y = pass_y + field_h + 12
        self.make_link(c, field_left + 5, links_y, "Forgot Password?", lambda: self.navigate("forgot"),
                        anchor="w", size=10)
        self.make_link(c, field_right - 5, links_y, "Sign up", lambda: self.navigate("signup_details"),
                        anchor="e", size=10)

        button_y = min(links_y + 70, h - 150)
        self.make_button(c, field_left, button_y, field_right, 53, "Login", self.try_login)

        footer_y = button_y + 92
        c.create_text(center, footer_y, text="If you are creating a new account,",
                       fill=MUTED, font=("Arial", 10))
        self.draw_underlined_line(c, center, footer_y + 21, [
            ("Terms & Conditions", True),
            (" and ", False),
            ("Privacy Policy", True),
            (" will apply.", False),
        ])

    def try_login(self):
        email = self.field_value("login_email", "Email:")
        password = self.field_value("login_password", "Password:")
        if not email or not password:
            messagebox.showwarning("Missing details", "Please enter your email and password.")
            return
        self.user["email"] = email
        self.navigate("dashboard")

    # Sign up

    def draw_signup_details(self, c, w, h):
        center = w / 2
        top_bottom = self.draw_top_panel(c, w, h)

        title_y = top_bottom + int((h - top_bottom) * 0.10)
        c.create_text(center, title_y, text="Personal details", fill=TEXT, font=("Arial", 24, "bold"))
        c.create_text(center, title_y + 26, text="Please fill in your login details.",
                       fill=MUTED, font=("Arial", 10))

        field_left, field_right = 50, w - 50
        field_h = 50
        first_y = title_y + 50
        last_y = first_y + field_h + 12

        self.make_field(c, field_left, first_y, field_right, field_h, "signup_first", "First name:")
        self.make_field(c, field_left, last_y, field_right, field_h, "signup_last", "Last name:")

        c.create_text(field_left + 5, last_y + field_h + 16, text="*Required information",
                       fill=MUTED, font=("Arial", 9), anchor="w")

        button_y = last_y + field_h + 40
        self.make_button(c, field_left, button_y, field_right, 53, "Continue", self.continue_signup)

    def continue_signup(self):
        first = self.field_value("signup_first", "First name:")
        last = self.field_value("signup_last", "Last name:")
        if not first or not last:
            messagebox.showwarning("Missing details", "Please enter your first and last name.")
            return
        self.user["first_name"] = first
        self.user["last_name"] = last
        self.navigate("create_account")

    def draw_create_account(self, c, w, h):
            center = w / 2
            top_bottom = self.draw_top_panel(c, w, h)
    
            title_y = top_bottom + int((h - top_bottom) * 0.10)
            c.create_text(center, title_y, text="Create your account", fill=TEXT, font=("Arial", 22, "bold"))
            c.create_text(center, title_y + 26, text="Please fill in your login details.",
                           fill=MUTED, font=("Arial", 10))
    
            field_left, field_right = 50, w - 50
            field_h = 50
            email_y = title_y + 50
            pass_y = email_y + field_h + 12
    
            self.make_field(c, field_left, email_y, field_right, field_h, "create_email", "Email:")
            self.make_field(c, field_left, pass_y, field_right, field_h, "create_password", "Password:", show="•")
    
            c.create_text(field_left + 5, pass_y + field_h + 16, text="*Required information",
                           fill=MUTED, font=("Arial", 9), anchor="w")
    
            button_y = pass_y + field_h + 40
            self.make_button(c, field_left, button_y, field_right, 53, "Create account", self.create_account)

    def create_account(self):
        email = self.field_value("create_email", "Email:")
        password = self.field_value("create_password", "Password:")
        if not email or not password:
            messagebox.showwarning("Missing details", "Please enter your email and password.")
            return
        self.user["email"] = email
        messagebox.showinfo("Smart Bin", "Account created successfully.")
        self.navigate("dashboard")

    # Forgot password

    def draw_forgot(self, c, w, h):
        center = w / 2
        top_bottom = self.draw_top_panel(c, w, h)

        title_y = top_bottom + int((h - top_bottom) * 0.12)
        c.create_text(center, title_y, text="Forgot your password?", fill=TEXT, font=("Arial", 20, "bold"))
        c.create_text(center, title_y + 26, text="Type your email so that we can send you the link.",
                       fill=MUTED, font=("Arial", 10))

        field_left, field_right = 50, w - 50
        field_h = 53
        email_y = title_y + 55

        self.make_field(c, field_left, email_y, field_right, field_h, "forgot_email", "Email:")

        button_y = email_y + field_h + 25
        self.make_button(c, field_left, button_y, field_right, 53, "Send email", self.send_reset_email)
        self.make_link(c, center, button_y + 80, "Back to Login", lambda: self.navigate("login"),
                        anchor="center", size=10)

    def send_reset_email(self):
        email = self.field_value("forgot_email", "Email:")
        if not email:
            messagebox.showwarning("Smart Bin", "Please enter your email.")
            return
        messagebox.showinfo("Smart Bin", "Password reset link sent to your email.")

    # Dashboard

    def draw_dashboard(self, c, w, h):
        header_bottom = self.draw_header_bar(c, w, "Smart Bin")

        # Profile avatar button, top-right of the header.
        avatar_r = 14
        ax, ay = w - 30, header_bottom / 2
        avatar_img = self.get_profile_avatar(avatar_r * 2)
        avatar_items = (c.create_image(ax, ay, image=avatar_img, anchor="center"),)
        for item in avatar_items:
            c.tag_bind(item, "<Button-1>", lambda e: self.navigate("profile"))
            c.tag_bind(item, "<Enter>", lambda e: c.config(cursor="hand2"))
            c.tag_bind(item, "<Leave>", lambda e: c.config(cursor=""))

        left, right = 15, w - 15

        # Points card
        points_y = header_bottom + 15
        points_h = 65
        rounded_rect(c, left, points_y, right, points_y + points_h, radius=18,
                     fill=COVER, outline="", width=0)
        logo = self.get_logo(30)
        c.create_image(left + 28, points_y + points_h / 2, image=logo, anchor="center")
        c.create_text(left + 58, points_y + points_h / 2 - 9, text=str(self.points),
                       fill=TEXT, font=("Arial", 19, "bold"), anchor="w")
        c.create_text(left + 58, points_y + points_h / 2 + 12, text="Available Points",
                       fill="#e5e5e5", font=("Arial", 8), anchor="w")

        # Coupons container
        coupons_y = points_y + points_h + 15
        coupons_h = 440
        rounded_rect(c, left, coupons_y, right, coupons_y + coupons_h, radius=16,
                     fill=CONTAINER, outline=BORDER, width=1)

        self.draw_coupon_row(c, left + 12, coupons_y + 15, right - 12, "20", 20)
        self.draw_coupon_row(c, left + 12, coupons_y + 79, right - 12, "50", 50)

        # Code redeem card
        code_y = coupons_y + coupons_h + 15
        code_h = 140
        rounded_rect(c, left, code_y, right, code_y + code_h, radius=16,
                     fill=CONTAINER, outline=BORDER, width=1)
        c.create_text(left + 14, code_y + 20, text="Code", fill=TEXT,
                       font=("Arial", 12, "bold"), anchor="w")
        self.make_field(c, left + 12, code_y + 32, right - 12, 44, "dashboard_code", "Type the code here")
        self.make_button(c, right - 100, code_y + 86, right - 12, 34, "Redeem", self.redeem_code, radius=10)

    def draw_coupon_row(self, c, x1, y1, x2, label, cost):
        row_h = 52
        rounded_rect(c, x1, y1, x2, y1 + row_h, radius=14, fill=BLACK, outline="", width=0)
        c.create_text(x1 + 16, y1 + row_h / 2, text=label, fill=TEXT,
                       font=("Arial", 17, "bold"), anchor="w")
        c.create_text(x1 + 55, y1 + row_h / 2, text="GET COUPON", fill=MUTED,
                       font=("Arial", 8), anchor="w")
        self.make_button(c, x2 - 62, y1 + 11, x2 - 12, row_h - 22, "GET",
                          lambda: self.get_coupon(cost), radius=10)

    def get_coupon(self, cost):
        if self.points >= cost:
            self.points -= cost
            self.current_code = f"SB-{cost}-{self.points:03d}"
            messagebox.showinfo(
                "Coupon Generated",
                f"Your coupon code is:\n\n{self.current_code}\n\nRemaining points: {self.points}"
            )
            self.navigate("dashboard")
        else:
            messagebox.showwarning("Smart Bin", "You do not have enough points.")

    def redeem_code(self):
        code = self.field_value("dashboard_code", "Type the code here")
        if code:
            messagebox.showinfo("Smart Bin", f"Code '{code}' submitted.")
        else:
            messagebox.showwarning("Smart Bin", "Please enter a code.")

    # Profile

    def draw_profile(self, c, w, h):
        center = w / 2
        left, right = 25, w - 25

        # Gray cover banner (doubles as the top of the page, per the design).
        cover_h = 125
        c.create_rectangle(0, 0, w, cover_h, fill=COVER, outline="")

        # Small unobtrusive back control over the banner.
        back = c.create_text(20, 20, text="‹ Dashboard", fill="#e8e8e8",
                              font=("Arial", 10, "bold"), anchor="w")
        c.tag_bind(back, "<Button-1>", lambda e: self.navigate("dashboard"))
        c.tag_bind(back, "<Enter>", lambda e: c.config(cursor="hand2"))
        c.tag_bind(back, "<Leave>", lambda e: c.config(cursor=""))

        # Avatar overlapping the bottom edge of the banner, with an edit badge.
        r = 34
        avatar_y = cover_h
        avatar_img = self.get_profile_avatar(r * 2)
        c.create_image(center, avatar_y, image=avatar_img, anchor="center")
        c.create_oval(center - r, avatar_y - r, center + r, avatar_y + r,
                      outline=BG, width=3)
        badge = c.create_oval(center + r - 16, avatar_y - 16, center + r + 8, avatar_y + 8,
                               fill=TEXT, outline=BG, width=2)
        badge_txt = c.create_text(center + r - 4, avatar_y - 4, text="✎",
                                   fill="#222222", font=("Arial", 9, "bold"))
        for tag in (badge, badge_txt):
            c.tag_bind(tag, "<Button-1>", lambda e: self.navigate("edit_profile"))
            c.tag_bind(tag, "<Enter>", lambda e: c.config(cursor="hand2"))
            c.tag_bind(tag, "<Leave>", lambda e: c.config(cursor=""))

        name = f"{self.user['first_name']} {self.user['last_name']}".strip() or "Smart Bin User"
        name_y = avatar_y + r + 20
        email_y = name_y + 18
        c.create_text(center, name_y, text=name, fill=TEXT, font=("Arial", 12, "bold"))
        c.create_text(center, email_y, text=self.user["email"] or "No email on file",
                       fill=MUTED, font=("Arial", 9))

        section_y = email_y + 30
        logo = self.get_logo(18)
        c.create_image(left, section_y, image=logo, anchor="w")
        acc_text_x = left + 24
        c.create_text(acc_text_x, section_y, text="Account", fill=TEXT,
                       font=("Arial", 13, "bold"), anchor="w")

        row_h = 44
        options = [
            ("Personal details", lambda: self.navigate("personal_details")),
            ("Password & Security", lambda: self.navigate("change_password")),
            ("Log out", self.confirm_logout),
        ]
        y = section_y + 20
        for text, command in options:
            color = RED if text == "Log out" else TEXT
            item = c.create_text(left + 4, y + row_h / 2, text=text, fill=color,
                                  font=("Arial", 11), anchor="w")
            arrow = c.create_text(right - 4, y + row_h / 2, text="›", fill=MUTED,
                                   font=("Arial", 16), anchor="e")
            for tag in (item, arrow):
                c.tag_bind(tag, "<Button-1>", lambda e, cmd=command: cmd())
                c.tag_bind(tag, "<Enter>", lambda e: c.config(cursor="hand2"))
                c.tag_bind(tag, "<Leave>", lambda e: c.config(cursor=""))
            c.create_line(left, y + row_h, right, y + row_h, fill=BORDER, width=1)
            y += row_h

    # Personal details (view + edit)

    def draw_personal_details(self, c, w, h):
        top_bottom = self.draw_top_panel(c, w, h, panel_height=int(h * 0.30))
        left, right = 50, w - 50
        center = w / 2

        title_y = top_bottom + int((h - top_bottom) * 0.14)
        c.create_text(center, title_y, text="Personal details", fill=TEXT, font=("Arial", 22, "bold"))

        rows = [
            ("First name:", self.user["first_name"] or "Not provided"),
            ("Last name:", self.user["last_name"] or "Not provided"),
            ("Email address:", self.user["email"] or "Not provided"),
            ("Phone number:", self.user["phone"] or "Not provided"),
        ]
        y = title_y + 40
        for label, value in rows:
            c.create_text(left, y, text=f"{label} {value}", fill=TEXT,
                           font=("Arial", 11), anchor="w")
            y += 26

        button_y = y + 20
        self.make_button(c, left, button_y, right, 50, "Edit profile",
                          lambda: self.navigate("edit_profile"))
        self.make_link(c, center, button_y + 80, "Go Back", lambda: self.navigate("profile"),
                        anchor="center", size=10)

    def draw_edit_profile(self, c, w, h):
        top_bottom = self.draw_top_panel(c, w, h, panel_height=int(h * 0.30))
        left, right = 50, w - 50
        center = w / 2

        title_y = top_bottom + int((h - top_bottom) * 0.14)
        c.create_text(center, title_y, text="Personal details", fill=TEXT, font=("Arial", 22, "bold"))

        # Pre-fill edit fields from the current user record the first
        # time this screen is shown after coming from personal details.
        for key, val in (
            ("edit_first", self.user["first_name"]),
            ("edit_last", self.user["last_name"]),
            ("edit_phone", self.user["phone"]),
        ):
            if self.get_var(key).get() == "":
                self.get_var(key).set(val)

        field_h = 44
        gap = 12

        y = title_y + 35
        self.make_field(c, left, y, right, field_h, "edit_first", "First name:")
        y += field_h + gap
        self.make_field(c, left, y, right, field_h, "edit_last", "Last name:")
        y += field_h + gap

        rounded_rect(c, left, y, right, y + field_h, radius=15, fill=BG, outline=BORDER, width=1)
        c.create_text(left + 14, y + field_h / 2, text=f"Email:  {self.user['email']}" if self.user["email"] else "Email:",
                       fill=MUTED, font=("Arial", 13), anchor="w")
        y += field_h + 4
        c.create_text(left + 4, y, text="*email address cannot be changed", fill=MUTED,
                       font=("Arial", 8), anchor="w")
        y += gap + 8

        self.make_field(c, left, y, right, field_h, "edit_phone", "Phone number:")
        y += field_h + 25

        self.make_button(c, left, y, (left + right) / 2 - 6, 46, "Cancel",
                          self.cancel_edit_profile, bg="#8a8a8a")
        self.make_button(c, (left + right) / 2 + 6, y, right, 46, "Save Changes", self.save_profile)

    def cancel_edit_profile(self):
        for key in ("edit_first", "edit_last", "edit_phone"):
            self._vars.pop(key, None)
        self.navigate("personal_details")

    def save_profile(self):
        self.user["first_name"] = self.field_value("edit_first", "First name:")
        self.user["last_name"] = self.field_value("edit_last", "Last name:")
        self.user["phone"] = self.field_value("edit_phone", "Phone number:")
        # Clear cached edit-field text so the next visit re-loads fresh values.
        for key in ("edit_first", "edit_last", "edit_phone"):
            self._vars.pop(key, None)
        self.navigate("personal_details")

    # Change password

    def draw_change_password(self, c, w, h):
        center = w / 2
        top_bottom = self.draw_top_panel(c, w, h)
        left, right = 50, w - 50

        title_y = top_bottom + int((h - top_bottom) * 0.14)
        c.create_text(center, title_y, text="Change password", fill=TEXT, font=("Arial", 22, "bold"))

        field_h = 53
        new_y = title_y + 40
        confirm_y = new_y + field_h + 12

        self.make_field(c, left, new_y, right, field_h, "new_password", "New Password:", show="•")
        self.make_field(c, left, confirm_y, right, field_h, "confirm_password", "Re-enter Password:", show="•")

        button_y = confirm_y + field_h + 25
        self.make_button(c, left, button_y, right, 53, "Reset Password", self.reset_password)
        self.make_link(c, center, button_y + 80, "Go Back", lambda: self.navigate("profile"),
                        anchor="center", size=10)

    def reset_password(self):
        new_pass = self.field_value("new_password", "New Password:")
        confirm = self.field_value("confirm_password", "Re-enter Password:")
        if not new_pass or not confirm:
            messagebox.showwarning("Smart Bin", "Please fill in both password fields.")
            return
        if new_pass != confirm:
            messagebox.showwarning("Smart Bin", "Passwords do not match.")
            return
        for key in ("new_password", "confirm_password"):
            self._vars.pop(key, None)
        messagebox.showinfo("Smart Bin", "Password changed successfully.")
        self.navigate("profile")

    # Log out confirmation modal
    
    def confirm_logout(self):
        # White modal, matching the design mockup (a deliberate contrast
        # against the rest of the app's dark theme, same as the reference).
        modal = tk.Toplevel(self.root)
        modal.title("Smart Bin")
        modal.configure(bg="#ffffff")
        modal.resizable(False, False)
        modal.transient(self.root)
        modal.grab_set()

        self.root.update_idletasks()
        mw, mh = 300, 170
        x = self.root.winfo_rootx() + (self.root.winfo_width() - mw) // 2
        y = self.root.winfo_rooty() + (self.root.winfo_height() - mh) // 2
        modal.geometry(f"{mw}x{mh}+{x}+{y}")

        tk.Label(
            modal, text="Are you sure you want to log out?",
            font=("Arial", 11, "bold"), fg="#111111", bg="#ffffff",
            wraplength=260, justify="center"
        ).pack(pady=(24, 6), padx=20)

        tk.Label(
            modal, text="If you log out now, you will not be able to use deals or rewards.",
            font=("Arial", 9), fg="#666666", bg="#ffffff", wraplength=260, justify="center"
        ).pack(padx=20)

        btns = tk.Frame(modal, bg="#ffffff")
        btns.pack(pady=22)

        def cancel():
            modal.destroy()

        def logout():
            modal.destroy()
            self.navigate("login")

        tk.Button(
            btns, text="Cancel", command=cancel,
            font=("Arial", 10, "bold"), fg="#666666", bg="#ffffff",
            activebackground="#ffffff", activeforeground="#444444",
            relief="flat", bd=0, cursor="hand2", padx=14
        ).pack(side="left", padx=10)

        tk.Button(
            btns, text="Log out", command=logout,
            font=("Arial", 10, "bold"), fg=RED, bg="#ffffff",
            activebackground="#ffffff", activeforeground=RED,
            relief="flat", bd=0, cursor="hand2", padx=14
        ).pack(side="left", padx=10)


if __name__ == "__main__":
    root = tk.Tk()
    app = SmartBinLogin(root)
    root.mainloop()
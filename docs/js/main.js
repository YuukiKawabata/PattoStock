/* ============================================
   Patto Landing Page - main.js
   ============================================ */

// --- Scroll Reveal ---
const revealElements = document.querySelectorAll('.reveal');

const revealObserver = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
        revealObserver.unobserve(entry.target);
      }
    });
  },
  { threshold: 0.12 }
);

revealElements.forEach((el) => revealObserver.observe(el));

// --- Navbar Scroll Effect ---
const navbar = document.querySelector('.navbar');

window.addEventListener('scroll', () => {
  if (window.scrollY > 10) {
    navbar.style.background = 'rgba(255,255,255,0.95)';
  } else {
    navbar.style.background = 'rgba(255,255,255,0.85)';
  }
}, { passive: true });

// --- Mobile Menu Toggle ---
const menuToggle = document.querySelector('.navbar-menu-toggle');
const navLinks = document.querySelector('.navbar-links');

if (menuToggle && navLinks) {
  menuToggle.addEventListener('click', () => {
    navLinks.classList.toggle('open');
    const isOpen = navLinks.classList.contains('open');
    menuToggle.setAttribute('aria-expanded', isOpen);
  });

  // Close menu when a link is clicked
  navLinks.querySelectorAll('a').forEach((link) => {
    link.addEventListener('click', () => {
      navLinks.classList.remove('open');
    });
  });

  // Close on outside click
  document.addEventListener('click', (e) => {
    if (!navbar.contains(e.target)) {
      navLinks.classList.remove('open');
    }
  });
}

// --- Smooth Scroll for anchor links ---
document.querySelectorAll('a[href^="#"]').forEach((anchor) => {
  anchor.addEventListener('click', (e) => {
    const href = anchor.getAttribute('href');
    if (href === '#') return;
    const target = document.querySelector(href);
    if (target) {
      e.preventDefault();
      const offset = 70;
      const top = target.getBoundingClientRect().top + window.scrollY - offset;
      window.scrollTo({ top, behavior: 'smooth' });
    }
  });
});

// --- Status dot pulse animation for hero mock ---
const dots = document.querySelectorAll('.iphone-item-dot');
let dotIndex = 0;

function pulseDots() {
  dots.forEach((dot, i) => {
    dot.style.transform = i === dotIndex ? 'scale(1.3)' : 'scale(1)';
    dot.style.transition = 'transform 0.3s ease';
  });
  dotIndex = (dotIndex + 1) % dots.length;
}

if (dots.length) {
  setInterval(pulseDots, 1800);
}

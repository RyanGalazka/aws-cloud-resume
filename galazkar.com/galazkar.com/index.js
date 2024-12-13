document.addEventListener('DOMContentLoaded', () => {
    const navLinks = document.querySelectorAll('.nav-link');
    const sections = document.querySelectorAll('.section');
    const counter = document.querySelector(".counter-number");
    const themeToggle = document.querySelector('#theme-toggle');
    const postsContainer = document.querySelector('.posts-container');

    // Visitor Counter
    if (counter) {
        async function updateCounter() {
            try {
                const response = await fetch("https://e3ttrvtvipqlvarijvbesnn7um0kcnix.lambda-url.us-east-1.on.aws/");
                if (!response.ok) {
                    throw new Error(`HTTP error! Status: ${response.status}`);
                }
                const data = await response.json();
                counter.innerHTML = `You are viewer: ${data}`;
            } catch (error) {
                console.error('Error in updateCounter:', error);
            }
        }
        updateCounter();
    } else {
        console.warn('Counter element not found. Skipping visitor count update.');
    }

    // Dark Mode Toggle
    if (themeToggle) {
        themeToggle.addEventListener('click', () => {
            document.body.classList.toggle('dark');
            const icon = themeToggle.querySelector('i');
            if (document.body.classList.contains('dark')) {
                icon.classList.replace('fa-moon', 'fa-sun');
            } else {
                icon.classList.replace('fa-sun', 'fa-moon');
            }
        });
    }

    // Function to switch sections
    function switchSection(sectionId) {
        sections.forEach(section => {
            section.style.display = 'none';
            section.classList.remove('active');
        });

        const selectedSection = document.getElementById(sectionId);
        if (selectedSection) {
            selectedSection.style.display = 'block';
            selectedSection.classList.add('active');
        }

        // Always scroll to the top
        window.scrollTo(0, 0);

        // Update URL hash based on the section, but not for the 'home' section
        if (sectionId !== 'home') {
            window.history.pushState(null, '', `#${sectionId}`);
        } else {
            window.history.pushState(null, '', '/'); // Remove hash for home
        }
    }

    // Handle initial load or hash change
    function handleInitialNavigation() {
        const hash = window.location.hash.substring(1);
        const sectionId = hash || 'home'; // Default to 'home' if no hash present
        switchSection(sectionId);
    }

    // Add click event listeners to nav links
    navLinks.forEach(link => {
        link.addEventListener('click', (event) => {
            event.preventDefault();
            const sectionId = link.getAttribute('data-section');
            switchSection(sectionId);
        });
    });

    window.addEventListener('hashchange', handleInitialNavigation);

    // Ensure initial state is correct
    handleInitialNavigation();

    // Ensure the page starts at the top on load (in case the page was loaded with a hash)
    window.scrollTo(0, 0);

    // Fetch Medium Posts
    const MEDIUM_FEED_URL = 'https://api.rss2json.com/v1/api.json?rss_url=https://medium.com/feed/@galazkaryan';

    async function fetchMediumPosts() {
        try {
            const response = await fetch(MEDIUM_FEED_URL);
            if (!response.ok) {
                throw new Error('Failed to fetch posts');
            }
            const data = await response.json();
            renderPosts(data.items);
        } catch (error) {
            console.error('Error fetching Medium posts:', error);
            postsContainer.innerHTML = `
                <div class="error-message">
                    <p>Unable to load Medium posts. Please check back later.</p>
                </div>
            `;
        }
    }

    function renderPosts(posts) {
        if (!posts || posts.length === 0) {
            postsContainer.innerHTML = '<p>No posts found.</p>';
            return;
        }

        const postsHTML = posts.map(post => `
            <div class="post">
                <img 
                    src="${post.thumbnail || '/path/to/default-thumbnail.jpg'}" 
                    alt="${post.title}" 
                    class="post-thumbnail"
                />
                <div class="post-content">
                    <h3 class="post-title">
                        <a href="${post.link}" target="_blank" rel="noopener noreferrer">
                            ${post.title}
                        </a>
                    </h3>
                    <p class="post-description">${post.description}</p>
                </div>
                <div class="post-meta">
                    <span class="post-date">${new Date(post.pubDate).toLocaleDateString()}</span>
                    <a href="${post.link}" target="_blank" rel="noopener noreferrer" class="read-more">
                        Read More
                    </a>
                </div>
            </div>
        `).join('');

        postsContainer.innerHTML = postsHTML;
    }

    // Fetch posts on page load
    if (postsContainer) {
        fetchMediumPosts();
    } else {
        console.warn('Posts container not found. Skipping Medium posts fetch.');
    }
});

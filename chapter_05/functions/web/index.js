const fs = require('fs');
const path = require('path');

// Lambda handler for serving static files
exports.handler = async (event) => {
    console.log('Web request:', event.rawPath);

    try {
        // Parse file path: / → index.html, /styles.css → styles.css
        let file = 'index.html';
        if (event.rawPath && event.rawPath !== '/') {
            file = event.rawPath.substring(1); // Remove leading /
        }

        const ext = file.split('.').pop();
        const filePath = path.resolve(__dirname, `./public/${file}`);

        console.log('Serving file:', file, 'from path:', filePath);
        console.log('File exists:', fs.existsSync(filePath));

        // Check if file exists
        if (!fs.existsSync(filePath)) {
            return {
                statusCode: 404,
                headers: { 'Content-Type': 'text/plain' },
                body: 'File not found'
            };
        }

        // Serve text files (HTML, CSS, JS)
        if (['html', 'css', 'js'].includes(ext)) {
            const contentType = `text/${ext === 'js' ? 'javascript' : ext}`;
            const body = fs.readFileSync(filePath, { encoding: 'utf-8' });

            return {
                statusCode: 200,
                headers: { 'Content-Type': contentType },
                body: body
            };
        }

        // Serve binary files (images, etc.)
        const bitmap = fs.readFileSync(filePath);
        const contentType = `image/${ext}`;

        return {
            statusCode: 200,
            headers: { 'Content-Type': contentType },
            body: bitmap.toString('base64'),
            isBase64Encoded: true
        };
    } catch (error) {
        console.error('Error serving file:', error);
        return {
            statusCode: 500,
            headers: { 'Content-Type': 'text/plain' },
            body: 'Internal server error'
        };
    }
};

import { ImageResponse } from '@vercel/og';

export const config = {
  runtime: 'edge',
};

export default async function handler(request) {
  const { searchParams } = new URL(request.url);
  const title = searchParams.get('title') || 'Untitled';
  const author = searchParams.get('author') || '';

  // Five tab colors from Hermes
  const colors = ['#e07a5f', '#e0a05f', '#6b9e7a', '#5f8fc9', '#9a7ec8'];

  return new ImageResponse(
    {
      type: 'div',
      props: {
        style: {
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          backgroundColor: '#f5f5f0',
          fontFamily: 'monospace',
        },
        children: [
          // Top colored bars
          {
            type: 'div',
            props: {
              style: {
                display: 'flex',
                gap: '0px',
                width: '100%',
                height: '8px',
              },
              children: colors.map((color) => ({
                type: 'div',
                props: {
                  style: {
                    flex: 1,
                    backgroundColor: color,
                    height: '8px',
                  },
                },
              })),
            },
          },
          // Content area
          {
            type: 'div',
            props: {
              style: {
                flex: 1,
                display: 'flex',
                flexDirection: 'column',
                justifyContent: 'center',
                padding: '60px 80px',
              },
              children: [
                // Title
                {
                  type: 'div',
                  props: {
                    style: {
                      fontSize: title.length > 60 ? '40px' : '52px',
                      fontWeight: 700,
                      color: '#1a1a1a',
                      lineHeight: 1.3,
                      marginBottom: '20px',
                      maxHeight: '280px',
                      overflow: 'hidden',
                    },
                    children: title,
                  },
                },
                // Author
                ...(author
                  ? [
                      {
                        type: 'div',
                        props: {
                          style: {
                            fontSize: '24px',
                            color: '#999',
                            lineHeight: 1.4,
                          },
                          children: author,
                        },
                      },
                    ]
                  : []),
              ],
            },
          },
          // Footer attribution
          {
            type: 'div',
            props: {
              style: {
                display: 'flex',
                justifyContent: 'flex-end',
                padding: '0 80px 40px',
                fontSize: '20px',
                color: '#bbb',
              },
              children: 'dearhermes.com',
            },
          },
        ],
      },
    },
    {
      width: 1200,
      height: 630,
    },
  );
}

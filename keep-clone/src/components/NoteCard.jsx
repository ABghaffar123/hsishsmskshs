import { Trash2, MoreVertical } from 'lucide-react'

const NOTE_COLORS = [
  '#fff9c0', // yellow
  '#e3f2fd', // blue
  '#e8f5e9', // green
  '#f3e5f5', // purple
  '#ffebee', // red
  '#fff3e0', // orange
]

function NoteCard({ note, onDelete, onEdit }) {
  const colorIndex = note.color || 0

  return (
    <div
      className="note-card"
      style={{ backgroundColor: NOTE_COLORS[colorIndex % NOTE_COLORS.length ] }}
    >
      <div className="note-content">
        {note.title && <h3 className="note-title">{note.title}</h3>}
        {note.body && <p className="note-body">{note.body}</p>}
      </div>

      <div className="note-actions">
        <button onClick={() => onEdit(note)} className="edit-btn" title="Edit">
          ✏️
        </button>
        <button onClick={() => onDelete(note.id)} className="delete-btn" title="Delete">
          <Trash2 size={16} />
        </button>
      </div>

      {note.tags && note.tags.length > 0 && (
        <div className="note-tags">
          {note.tags.map((tag, index) => (
            <span key={index} className="tag">{tag}</span>
          ))}
        </div>
      )}
    </div>
  )
}

export default NoteCard
